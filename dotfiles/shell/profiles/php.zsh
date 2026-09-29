# DOTMOD Profile: DEV PHP (PHP, Laravel, Lumen)

# Composer shortcuts
alias comp="composer"
alias ci="composer install"
alias cu="composer update"
alias cda="composer dump-autoload"

# Laravel Artisan & Lumen shortcuts
alias art="php artisan"
alias arts="php artisan serve"
alias artm="php artisan migrate"
alias artmr="php artisan migrate:rollback"
alias artms="php artisan migrate:status"
alias artc="php artisan config:clear && php artisan cache:clear"
alias artr="php artisan route:list"
alias artq="php artisan queue:work"
alias tinker="php artisan tinker"

# Testing
alias pu="vendor/bin/phpunit"
alias pest="vendor/bin/pest"
