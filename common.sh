#!/bin/bash

# common_setup.sh
# Source this file in other scripts to use common TLS and package functions

# --------------------------------------------------------------------------
# Control whether to check Subject Alternative Names (SANs) in certificates
# Default: disabled (0)
# Set to 1 to enable searching all directories for SAN matches
# --------------------------------------------------------------------------
checkAlternativeSubjectNames=0

# --------------------------------------------------------------------------
# Function to check and install packages
# --------------------------------------------------------------------------
check_and_install() {
    local REQUIRED_PKGS=("$@")
    local MISSING_PKGS=()

    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! dpkg-query -W --showformat='${Status}\n' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            echo "$pkg is not installed."
            MISSING_PKGS+=("$pkg")
        else
            echo "$pkg is already installed."
        fi
    done

    if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
        echo
        echo "The following packages are missing: ${MISSING_PKGS[*]}"
        read -rp "Do you want to install them now? (y/n): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            apt update
            apt install -y "${MISSING_PKGS[@]}"
        else
            echo "Cannot proceed without required packages. Exiting."
            exit 1
        fi
    else
        echo "All required packages are already installed."
    fi
}

# --------------------------------------------------------------------------
# Function to print certificate domain names
# --------------------------------------------------------------------------
print_cert_domains() {
    local cert_file="$1"

    if [[ ! -f "$cert_file" ]]; then
        echo "Certificate file not found: $cert_file"
        return 1
    fi

    local cn
    cn=$(openssl x509 -noout -subject -in "$cert_file" 2>/dev/null \
        | sed -E 's/.*CN[[:space:]]*=[[:space:]]*([^,\/]*)/\1/')

    local sans
    sans=$(openssl x509 -noout -text -in "$cert_file" 2>/dev/null \
        | grep -A1 "X509v3 Subject Alternative Name" \
        | tail -n1 \
        | tr ',' '\n' \
        | sed 's/DNS://g' | sed 's/^[ \t]*//')

    echo "Certificate: $cert_file"
    echo "Common Name (CN): ${cn:-<none>}"

    if [[ -n "$sans" ]]; then
        echo "Subject Alternative Names (SANs):"
        for entry in $sans; do
            echo "  - $entry"
        done
    else
        echo "No SANs found in certificate."
    fi
}

# --------------------------------------------------------------------------
# Function to check if a certificate contains a domain in CN or SAN
# --------------------------------------------------------------------------
check_cert_for_domain() {
    local cert_file="$1"
    local domain="$2"

    if [[ ! -f "$cert_file" ]]; then
        return 1
    fi

    local cn
    cn=$(openssl x509 -noout -subject -in "$cert_file" 2>/dev/null \
        | sed -E 's/.*CN[[:space:]]*=[[:space:]]*([^,\/]*)/\1/')

    local sans
    sans=$(openssl x509 -noout -text -in "$cert_file" 2>/dev/null \
        | grep -A1 "X509v3 Subject Alternative Name" \
        | tail -n1 \
        | tr ',' '\n' \
        | sed 's/DNS://g' | sed 's/^[ \t]*//')

    for entry in $cn $sans; do
        if [[ "$entry" == "$domain" ]]; then
            return 0
        fi
    done

    return 1
}

# --------------------------------------------------------------------------
# Function to find existing certificate directory for a domain
# --------------------------------------------------------------------------
find_cert_dir() {
    local domain="$1"
    local base_dir="/etc/letsencrypt/live"

    # First, check if the base directory exists for the domain
    if [[ -d "${base_dir}/${domain}" ]]; then
        echo "${base_dir}/${domain}"
        return 0
    fi

    # Only search all directories if checkAlternativeSubjectNames is enabled
    if [[ "$checkAlternativeSubjectNames" -eq 1 ]]; then
        for dir in "$base_dir"/*; do
            local cert_file="${dir}/cert.pem"
            if check_cert_for_domain "$cert_file" "$domain"; then
                echo "$dir"
                return 0
            fi
        done
    fi

    return 1
}

# --------------------------------------------------------------------------
# Function to obtain TLS certificates using Certbot
# Accepts one or more domains
# Sets global variables for TLS file paths
# --------------------------------------------------------------------------
obtain_cert() {
    local DOMAINS=("$@")
    if [ ${#DOMAINS[@]} -eq 0 ]; then
        echo "No domains provided to obtain_cert. Exiting."
        return 1
    fi

    # Check for existing certificate directories
    local existing_dir
    for domain in "${DOMAINS[@]}"; do
        if dir=$(find_cert_dir "$domain"); then
            existing_dir="$dir"
            break
        fi
    done

    # If found, set TLS file variables
    if [[ -n "$existing_dir" ]]; then
        tls_cert="${existing_dir}/cert.pem"
        tls_chain="${existing_dir}/chain.pem"
        tls_fullchain="${existing_dir}/fullchain.pem"
        tls_privkey="${existing_dir}/privkey.pem"
        echo "Using existing certificate directory: $existing_dir"
        return 0
    fi

    # Ask user if they want to use Certbot
    echo "No existing certificate found."
    read -rp "Obtain a new certificate for domains: ${DOMAINS[*]}? (y/n): " use_certbot
    if [[ ! "$use_certbot" =~ ^[Yy]$ ]]; then
        echo "Skipping Certbot setup. TLS certificates will not be obtained."
        return 1
    fi

    # Ensure required packages
    check_and_install "certbot" "apache2"

    # Ensure ACME directory exists
    if [[ ! -d "/var/www/acme" ]]; then
        mkdir -p /var/www/acme
        chown www-data:www-data /var/www/acme
    fi

    # Create Apache config for ACME challenges
    if [[ ! -f "/etc/apache2/sites-available/acme.conf" ]]; then
        local acme_conf="/etc/apache2/sites-available/acme.conf"
        cat > "$acme_conf" <<EOF
<VirtualHost *:80>
	DocumentRoot /var/www/acme

	<Location /.well-known/acme-challenge/>
		Require all granted
	</Location>

	RewriteEngine On
	RewriteCond %{REQUEST_URI} !^/\.well-known/acme-challenge/
	RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [R=301,L]
</VirtualHost>
EOF
    fi

    # Enable config and reload Apache
    if [[ ! -f "/etc/apache2/sites-enabled/acme.conf" ]]; then
        a2ensite acme.conf
        systemctl enable apache2
        systemctl reload apache2 || systemctl restart apache2
    fi

    # Run Certbot for all domains
    echo "Running Certbot for domains: ${DOMAINS[*]}"
    certbot certonly --webroot -w /var/www/acme "${DOMAINS[@]/#/-d }"

    # Determine which directory was created
    local domain_dir="${DOMAINS[0]}"
    existing_dir="/etc/letsencrypt/live/${domain_dir}"

    # Set TLS file variables
    tls_cert="${existing_dir}/cert.pem"
    tls_chain="${existing_dir}/chain.pem"
    tls_fullchain="${existing_dir}/fullchain.pem"
    tls_privkey="${existing_dir}/privkey.pem"

    echo "TLS certificates obtained and variables set:"
    echo "tls_cert=$tls_cert"
    echo "tls_chain=$tls_chain"
    echo "tls_fullchain=$tls_fullchain"
    echo "tls_privkey=$tls_privkey"
}
