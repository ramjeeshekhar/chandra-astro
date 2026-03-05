# === Base image ===
FROM php:8.3-apache

# ==============================
# Allow UID/GID override (important!)
# ==============================
ARG UID=1001
ARG GID=1001

# Modify www-data to match host user
RUN groupmod -g ${GID} www-data \
    && usermod -u ${UID} -g ${GID} www-data

# === System dependencies ===
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libwebp-dev \
    libzip-dev \
    default-mysql-client \
    rsync \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install pdo_mysql zip gd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# === Enable Apache rewrite module ===
RUN a2enmod rewrite

# === Set working directory ===
WORKDIR /var/www/html

# === Install Composer ===
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ==============================
# Copy Drupal Project
# ==============================
COPY . /var/www/html

# === Install PHP dependencies ===
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts || true

# === Create the Entrypoint Script ===
# This script runs at container STARTUP to fix permissions on volumes.
COPY <<EOF /usr/local/bin/docker-entrypoint.sh
#!/bin/sh
set -e

echo "--- Drupal Startup: Handling Persistent Storage ---"

# Ensure the files directory exists
mkdir -p /var/www/html/web/sites/default/files

# Create settings.php if it does not exist
if [ ! -f /var/www/html/web/sites/default/settings.php ]; then
    echo "Copying default.settings.php to settings.php"
    cp /var/www/html/web/sites/default/default.settings.php /var/www/html/web/sites/default/settings.php
fi

# FIX PERMISSIONS: Ensure both www-data and r-pandey (group) can write
echo "Setting group-writable permissions..."
chown -R www-data:www-data /var/www/html/web/sites/default
chmod -R 775 /var/www/html/web/sites/default/files

echo "--- Drupal Startup: Complete ---"
exec "\$@"
EOF

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# ==============================
# Set Apache DocumentRoot to /web
# ==============================
RUN sed -i 's|/var/www/html|/var/www/html/web|g' /etc/apache2/sites-available/000-default.conf \
 && sed -i 's|/var/www/html|/var/www/html/web|g' /etc/apache2/apache2.conf

# ==============================
# Expose Port
# ==============================
EXPOSE 80

# ==============================
# Entrypoint + Command
# ==============================
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]