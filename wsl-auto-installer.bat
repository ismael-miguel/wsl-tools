@echo off
SetLocal EnableDelayedExpansion

REM Automatically installs a **NEW** WSL Distro image
REM 
REM ⚠️ Only supports Debian and Ubuntu
REM 
REM Usually, to install multiple of the same distro, you need to do it all manually
REM This reduces all the work of installing into a few simple steps
REM It does the following:
REM - Create the VM with a specific name and disk file
REM - Install Apache2, PHP (fpm or modphp, with Xdebug) and MariaDB
REM - Configures a local website automatically (with or without SSL enabled)
REM - Automatically creates a non-root user
REM - Allows you to interact with what can be interacted with, if you wish
REM After that, the VM is ready to use.
REM ⚠️ The VM will be shutdown after creating, to avoid issues
REM ⚠️ To avoid even more issues, will make sure that there are no running VMs
REM
REM You can find the disk images here:
REM Debian: https://salsa.debian.org/debian/WSL
REM Ubuntu: https://ubuntu.com/desktop/wsl
REM 
REM You can also find more files in:
REM https://github.com/microsoft/WSL/blob/master/distributions/DistributionInfo.json
REM To use these files in there:
REM 1- Find the "Distributions" key
REM 2- Look for the distro by the "Name" key
REM 3- Download the "Amd64PackageUrl" or the "Arm64PackageUrl" file, for your arch
REM 4- Open the .appx or .AppxBundle file with 7zip
REM 4.1- For the .AppxBundle, extract the .appx file for your arch
REM 4.2- Open the .appx file with 7zip
REM 5- Extract the "install.tar.gz" file
REM That's the file you need to select later on
REM This is the only way I found to get the install disk for older Ubuntu versions



REM Changes the codepage to UTF-8
REM https://stackoverflow.com/a/24135496
CHCP 65001 >nul


REM Windows path where the WSL installs will be added to
set "ROOT=%LOCALAPPDATA%\wsl"



REM Arrays start at 1, for this


REM Array of all OS types this can deal with
set "OS_TYPES[1]=Debian 12"
set "OS_TYPES[2]=Ubuntu 24.04"
set "OS_TYPES[3]=Ubuntu 22.04"
set "OS_TYPES[4]=Ubuntu 20.04"
set "OS_TYPES[5]=Ubuntu 18.04"
set "OS_TYPES.length=5"

REM Map between the OS and it's base type
set "OS_BASE_TYPE[%OS_TYPES[1]%]=Debian"
set "OS_BASE_TYPE[%OS_TYPES[2]%]=Ubuntu"
set "OS_BASE_TYPE[%OS_TYPES[3]%]=Ubuntu"
set "OS_BASE_TYPE[%OS_TYPES[4]%]=Ubuntu"
set "OS_BASE_TYPE[%OS_TYPES[5]%]=Ubuntu"

set "OS_TYPE=!OS_TYPES[1]!"


REM Username for the non-root user
set "OS_USER=test"


REM Name of the virtual machine, for WSL
set "VM_NAME="


REM Array of all PHP versions
set "PHP_VERSION[1]="
set "PHP_VERSION[2]=7.4"
set "PHP_VERSION[3]=8.0"
set "PHP_VERSION[4]=8.1"
set "PHP_VERSION[5]=8.2"
set "PHP_VERSION[6]=8.3"
set "PHP_VERSION[7]=8.4"
set "PHP_VERSION.length=7"

set "PHP_VERSION=!PHP_VERSION[1]!"

REM Xdebug settings
set "PHP_XDEBUG_PORT=9003"
set "PHP_XDEBUG_START_W_REQ=yes"



REM Defines if you wish to have MariaDB or not
set "MARIA_BD=0"


REM If it is to install Apache2 and how it interconnects with PHP
set "APACHE[1]="
set "APACHE[2]=fpm"
set "APACHE[3]=modphp"
set "APACHE.length=3"
set "APACHE_TYPE=!APACHE[1]!"


REM Domain name for the website to be automatically configured
set "APACHE_DOMAIN="
REM Root folder name for the website
set "APACHE_ROOT="
REM Automatically creates a certificate
set "APACHE_SSL=1"
REM Path where the website folder will be created into
set "APACHE_BASE_ROOT=/var/www"
REM PAth where the certificates for Apache will be
set "APACHE_CERTS_ROOT=/etc/apache2/certs"


REM Be aware that local and test are reserved: https://en.wikipedia.org/wiki/Special-use_domain_name
set "VALID_DOMAIN_TLDS=local test intranet internal private home lan"

set "INVALID_DOMAINS=localhost host local com null nil example.com"


REM Some things will be interactive, in the install
set "INTERACTIVE=0"



REM Must check if we're running on supported CPU arch

set "ARCH_SUPPORTED=0"
set "ARCH_SUPPORT_LIST=AMD64 ARM64"
FOR %%a IN (!ARCH_SUPPORT_LIST!) DO (
	IF %%a EQU %PROCESSOR_ARCHITECTURE% (
		set "ARCH_SUPPORTED=1"
	)
)


REM If it goes in, means we're NOT in a supported CPU arch
IF !ARCH_SUPPORTED! EQU 0 (
	echo ❌ Unsupported architecture: %PROCESSOR_ARCHITECTURE%
	echo Only supports: !ARCH_SUPPORT_LIST!

	exit /b 1
)



REM Check if there's a WSL machine running
FOR /f "usebackq tokens=* delims=" %%A IN (`wsl --list --running --quiet`) DO (
	echo ❌ The following VMs are running:
	
	REM Pretty wasteful, but it's the best I can do due to UTF-16 :/
	wsl --list --running --quiet
	
	echo.
	echo Stop *ALL* VMs and then try again
	echo This is needed to protect your other VMs from damage
	
	exit /b 1
)



REM The main UI starts here


:drawui
cls

echo [7m    WSL Auto installer    [0m
echo.
echo Root: [7m !ROOT! [0m
echo [R] Change the path
echo.

REM Clean this all the time, to prevent bad states
set "FULL_VM_NAME="

IF NOT "!VM_NAME!" EQU "" (
	echo VM Name: [7m ✅ !VM_NAME! [0m
	
	set "FULL_VM_NAME=!VM_NAME!-!OS_TYPE: =-!"

	call :vmexists "!FULL_VM_NAME!"
	IF !vmexists! EQU 1 (
		echo ❌ VM Name already exists
	) ELSE IF EXIST "!ROOT!\!FULL_VM_NAME!" (
		echo ❌ Folder !FULL_VM_NAME! already exists
	)
) ELSE (
	echo VM Name: [7m ❌ ^<none^> [0m        ⚠️  Required
)
echo [N] Change the name

echo.
echo OS type: [7m !OS_TYPE! [0m
echo [O] Change the OS type
echo.
echo Username: [7m !OS_USER! [0m
echo [U] Change the username
echo.


IF NOT "!PHP_VERSION!" EQU "" (
	echo PHP Version: [7m ✅ !PHP_VERSION! [0m
) ELSE (
	REM Apache2 is supposed to be installed with PHP
	set "APACHE_TYPE=!APACHE[0]!"
	
	REM And MariaDB is supposed to be used with PHP too
	set "MARIA_BD=0"
	
	echo PHP Version: [7m ❌ ^<none^> [0m
)

echo [P] Change the PHP Version
echo.


IF NOT "!APACHE_TYPE!" EQU "" (
	echo Apache2 type: [7m ✅ !APACHE_TYPE! [0m
) ELSE (
	echo Apache2 type: [7m ❌ ^<none^> [0m
)

IF NOT "!PHP_VERSION!" EQU "" (
	echo [A] Change Apache2 type
)


echo.


IF "!MARIA_BD!" EQU "1" (
	echo Install MariaDB? [7m ✅ Yes [0m
) ELSE (
	echo Install MariaDB? [7m ❌ No, skip [0m
)

IF NOT "!PHP_VERSION!" EQU "" (
	echo [M] Toggle install/skip
)


echo.


IF "!INTERACTIVE!" EQU "1" (
	echo Interactive? [7m ☑️ Yes [0m
) ELSE (
	echo Interactive? [7m ⬜ No [0m
)
echo [I] Toggle interactive yes/no

echo.


choice /c:cqimapuonr /n /m "[C] Continue | [Q] Quit"


IF ERRORLEVEL 3 (
	IF ERRORLEVEL 10 (
		call :getfolder "Select root folder"
		If NOT "!getfolder!" EQU "" (
			set "ROOT=!getfolder!"
		)
	) ELSE IF ERRORLEVEL 9 (
		call :input "Name of the VM: " "!VM_NAME!" false
		set "VM_NAME=!input: =_!"
	) ELSE IF ERRORLEVEL 8 (
		call :choice "Select the OS type" OS_TYPES "!OS_TYPE!" false
		set "OS_TYPE=!choice!"
	) ELSE IF ERRORLEVEL 7 (
		call :input "Username: " "!OS_USER!" false
		set "OS_USER=!input: =!"
	) ELSE IF ERRORLEVEL 6 (
		call :choice "Select a PHP version" PHP_VERSION "!PHP_VERSION!" true
		set "PHP_VERSION=!choice!"
	) ELSE IF ERRORLEVEL 5 (
		IF NOT "!PHP_VERSION!" EQU "" (
			call :apache_config
		)
	) ELSE IF ERRORLEVEL 4 (
		IF NOT "!PHP_VERSION!" EQU "" (
			IF "!MARIA_BD!" EQU "1" (
				set "MARIA_BD=0"
			) ELSE (
				set "MARIA_BD=1"
			)
		)
	) ELSE IF ERRORLEVEL 3 (
		IF "!INTERACTIVE!" EQU "1" (
			set "INTERACTIVE=0"
		) ELSE (
			set "INTERACTIVE=1"
		)
	)
	
	goto :drawui
) ELSE IF ERRORLEVEL 2 (
	cls
	exit /b 255
)


REM The [C] Continue option was selected


REM A name is mandatory
IF [!VM_NAME!] EQU [] (
	goto :drawui
)

IF [!FULL_VM_NAME!] EQU [] (
	goto :drawui
)


REM We will need these extensively later on
set "OS_BASE_TYPE=!OS_BASE_TYPE[%OS_TYPE%]!"


REM We need to confirm that the WM doesn't exist
call :vmexists "!FULL_VM_NAME!"
IF !vmexists! EQU 1 (
	goto :drawui
)



REM We need the disk image file
REM There are multiple formats in which the installation image may be:
REM - wsl - Seems to be a .tar.gz file, renamed for WSL - used by Ubuntu
REM - tar - A custom install disk that may have been extracted
REM - tar.gz - An install disk that's compressed - used by Debian
call :getfile "Select the !OS_TYPE! image file" "All Archives (*.wsl;*.tar;*.tar.gz)| *.wsl;*.tar;*tar.gz|WSL Archive (*.wsl)| *.wsl|TAR Archive (*.tar)| *.tar|GZ Tarball Archive (*.tar.gz)| *.tar.gz"

IF [!getfile!] EQU [] (
	goto :drawui
)




REM Happy path!



echo.
echo Creating the machine !FULL_VM_NAME! ...
echo.



mkdir "!ROOT!\!FULL_VM_NAME!"
IF ERRORLEVEL 1 (
	exit /b !ERRORLEVEL!
)

wsl --import "!FULL_VM_NAME!" "!ROOT!\!FULL_VM_NAME!" "!getfile!"
IF ERRORLEVEL 1 (
	exit /b !ERRORLEVEL!
)


REM Make sure it is updated
call :runonvm !FULL_VM_NAME! "apt update && apt upgrade -y"
IF !runonvm! GTR 0 (
	exit /b !runonvm!
)


REM Install base packages
set "packages=wget curl openssl git htop"
IF !OS_BASE_TYPE! EQU Debian (
	REM These will be needed for PHP, only for Debian
	IF NOT [!PHP_VERSION!] EQU [] (
		set "packages=apt-transport-https lsb-release ca-certificates !packages!"
	)
)

call :runonvm !FULL_VM_NAME! "apt install !packages! -y"
IF !runonvm! GTR 0 (
	exit /b !runonvm!
)




REM Install PHP and Apache2
IF NOT [!PHP_VERSION!] EQU [] (
	set "PHP_INI_ROOT=/etc/php/!PHP_VERSION!"
	set "PHP_INI_TYPES=apache2"
	IF !APACHE_TYPE! EQU fpm (
		set "PHP_INI_TYPES=!PHP_INI_TYPES! fpm"
	)
	
	
	set "packages=cli,common,curl,gd,intl,mbstring,mcrypt,memcache,memcached,mysql,opcache,pdo,phpdbg,readline,sqlite3,xdebug,xml,zip"
	
	REM This package isn't available for newer versions
	IF !PHP_VERSION! LEQ 7.4 (
		set "packages=!packages!,json"
	)
	
	
	REM install the PHP Sury's Package provider
	IF !OS_BASE_TYPE! EQU Debian (
		call :runonvm !FULL_VM_NAME! "curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb"
		call :runonvm !FULL_VM_NAME! "dpkg -i /tmp/debsuryorg-archive-keyring.deb"
		call :runonvm !FULL_VM_NAME! "echo 'deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main' > /etc/apt/sources.list.d/php.list"
	) ELSE IF !OS_BASE_TYPE! EQU Ubuntu (
		call :runonvm !FULL_VM_NAME! "LC_ALL=C.UTF-8 add-apt-repository --yes ppa:ondrej/php"
		call :runonvm !FULL_VM_NAME! "LC_ALL=C.UTF-8 add-apt-repository --yes ppa:ondrej/apache2"
	)
	
	call :runonvm !FULL_VM_NAME! "apt update"
	
	call :runonvm !FULL_VM_NAME! "apt install php!PHP_VERSION! php!PHP_VERSION!-{!packages!} -y"
	IF !runonvm! GTR 0 (
		exit /b !runonvm!
	)
	
	
	REM Handle Apache2 installation and fpm/modphp
	IF NOT [!APACHE_TYPE!] EQU [] (
		call :runonvm !FULL_VM_NAME! "apt install libapache2-mod-php!PHP_VERSION! -y"
		IF !runonvm! GTR 0 (
			exit /b !runonvm!
		)
		
		IF !APACHE_TYPE! EQU fpm (
			call :runonvm !FULL_VM_NAME! "apt install php!PHP_VERSION!-fpm -y"
			IF !runonvm! GTR 0 (
				exit /b !runonvm!
			)
			
			REM We won't need this running
			call :runonvm !FULL_VM_NAME! "service php!PHP_VERSION!-fpm stop"
			
			REM We need to:
			REM - Disable phpmod, to it won't interfeer with php-fpm
			REM - Enable the proxy_fcgi module to handle php-fpm
			REM - Enable the setenvif module because of the warnings
			REM - Enable the php-fpm configuration
			call :runonvm !FULL_VM_NAME! "a2dismod php!PHP_VERSION! && a2enmod proxy_fcgi setenvif && a2enconf php!PHP_VERSION!-fpm"
		) ELSE IF !APACHE_TYPE! EQU modphp (
			call :runonvm !FULL_VM_NAME! "a2enmod php!PHP_VERSION!"
		)
		
		
		REM Required for many projects
		call :runonvm !FULL_VM_NAME! "a2enmod rewrite"
		
		
		REM Just detects if we need to configure the site or not
		set "APACHE_CONFIG_SITE=0"
		IF NOT [!APACHE_DOMAIN!] EQU [] (
			IF NOT [!APACHE_ROOT!] EQU [] (
				set "APACHE_CONFIG_SITE=1"
			)
		)
		
		IF !APACHE_CONFIG_SITE! EQU 1 (
			IF !APACHE_SSL! EQU 1 (
				REM pre-builds the certificates
				call :runonvm !FULL_VM_NAME! "a2enmod ssl"
				call :runonvm !FULL_VM_NAME! "mkdir -p !APACHE_CERTS_ROOT!"
				
				set "silence="
				IF !INTERACTIVE! EQU 0 (
					set "silence=-subj '/C=AU/ST=Denial'"
				)
				
				call :runonvm !FULL_VM_NAME! "openssl req -new -newkey rsa:4096 -x509 !silence! -sha256 -days 3660 -nodes -out !APACHE_CERTS_ROOT!/apache.crt -keyout !APACHE_CERTS_ROOT!/apache.key"
			)
			
			set "root=!APACHE_BASE_ROOT!/!APACHE_ROOT!"
			
			call :runonvm !FULL_VM_NAME! "mkdir -p !root!"
			
			REM Test PHP file to make sure everything is running
			call :runonvm !FULL_VM_NAME! "echo '<?php phpinfo();' >> !root!/index.php"
			
			REM Creates the .xdebug folder, for all Xdebug needs
			call :runonvm !FULL_VM_NAME! "mkdir -p !root!/.xdebug"
			
			call :runonvm !FULL_VM_NAME! "chown -R www-data:www-data !root!"
			
			
			set "config=/etc/apache2/sites-available/!APACHE_DOMAIN!.conf"
			
			echo Writing the !APACHE_DOMAIN!.conf file ...
			
			call :runonvm !FULL_VM_NAME! "echo '<VirtualHost *:80>' >> !config!"
			call :runonvm !FULL_VM_NAME! "echo '	ServerName !APACHE_DOMAIN!' >> !config!"
			call :runonvm !FULL_VM_NAME! "echo '	DocumentRoot !root!' >> !config!"
			call :runonvm !FULL_VM_NAME! "echo '	ErrorLog \${APACHE_LOG_DIR}/error.log' >> !config!"
			call :runonvm !FULL_VM_NAME! "echo '	' >> !config!"
			call :runonvm !FULL_VM_NAME! "echo '	DirectoryIndex index.php index.html index.htm' >> !config!"
			call :runonvm !FULL_VM_NAME! "echo '	' >> !config!"
			
			call :runonvm !FULL_VM_NAME! "echo '	<Directory !root!>' >> !config!"
			call :runonvm !FULL_VM_NAME! "echo '		Options -Indexes' >> !config!"
			
			IF !APACHE_SSL! EQU 1 (
				call :runonvm !FULL_VM_NAME! "echo '		<IfModule mod_rewrite.c>' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '			# Forces a redirect to https' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '			RewriteEngine on' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo $'			RewriteCond \x25{HTTPS} \x21=on' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '			RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R=301,QSA,L]' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '		</IfModule>' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	</Directory>' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '</VirtualHost>' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '<VirtualHost *:443>' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	ServerName !APACHE_DOMAIN!' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	DocumentRoot !root!' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	ErrorLog \${APACHE_LOG_DIR}/error.log' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	DirectoryIndex index.php index.html index.htm' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	SSLEngine on' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	SSLCertificateFile !APACHE_CERTS_ROOT!/apache.crt' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	SSLCertificateKeyFile !APACHE_CERTS_ROOT!/apache.key' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	<Directory !root!>' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '		Options -Indexes' >> !config!"
			)
			
			call :runonvm !FULL_VM_NAME! "echo '		AllowOverride All' >> !config!"
			call :runonvm !FULL_VM_NAME! "echo '	</Directory>' >> !config!"
			
			IF !APACHE_TYPE! EQU fpm (
				call :runonvm !FULL_VM_NAME! "echo '	<FilesMatch \.php$>' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo $'		SetHandler \x22proxy:unix:/run/php/php!PHP_VERSION!-fpm.sock\x7cfcgi://localhost/\x22' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	</FilesMatch>' >> !config!"
				call :runonvm !FULL_VM_NAME! "echo '	' >> !config!"
			)
			
			call :runonvm !FULL_VM_NAME! "echo '</VirtualHost>' >> !config!"
			
			call :runonvm !FULL_VM_NAME! "a2ensite !APACHE_DOMAIN!"
		)
		
		REM We need to keep apache stopped, or it may cause errors
		call :runonvm !FULL_VM_NAME! "service apache2 stop"
		
		
		
		FOR %%t IN (!PHP_INI_TYPES!) DO (
			set "phpini=!PHP_INI_ROOT!/%%t/php.ini"
			
			echo Writing the !phpini! file ...
			
			call :runonvm !FULL_VM_NAME! "echo '' >> !phpini!"
			call :runonvm !FULL_VM_NAME! "echo '[xdebug]' >> !phpini!"
			call :runonvm !FULL_VM_NAME! "echo 'xdebug.mode=develop,debug' >> !phpini!"
			call :runonvm !FULL_VM_NAME! "echo 'xdebug.start_with_request = !PHP_XDEBUG_START_W_REQ!' >> !phpini!"
			call :runonvm !FULL_VM_NAME! "echo 'xdebug.use_compression = false' >> !phpini!"
			call :runonvm !FULL_VM_NAME! "echo $'xdebug.output_dir=\x22!root!/.xdebug\x22' >> !phpini!"
			call :runonvm !FULL_VM_NAME! "echo $'xdebug.trace_output_name = trace.\x25u-\x25p' >> !phpini!"
			call :runonvm !FULL_VM_NAME! "echo $'xdebug.profiler_output_name = callgrind.out.\x25u-\x25p' >> !phpini!"
			call :runonvm !FULL_VM_NAME! "echo 'xdebug.client_port = !PHP_XDEBUG_PORT!' >> !phpini!"
		)
	)
)



IF !MARIA_BD! EQU 1 (
	call :runonvm !FULL_VM_NAME! "apt install mariadb-server -y"
	IF !runonvm! EQU 0 (
		REM Run if the installation succeeded
		
		IF !INTERACTIVE! EQU 0 (
			REM https://stackoverflow.com/a/27759061
			REM https://stackoverflow.com/questions/24270733/automate-mysql-secure-installation-with-echo-command-via-a-shell-script
			
			REM Kill the anonymous users
			call :runonvm !FULL_VM_NAME! "mysql -e $'DROP USER \x27\x27@\x27localhost\x27'"
			REM Because our hostname varies we'll use some Bash magic here.
			call :runonvm !FULL_VM_NAME! "mysql -e $'DROP USER \x27\x27@\x27$(hostname)\x27'"
			REM Kill off the demo database
			call :runonvm !FULL_VM_NAME! "mysql -e 'DROP DATABASE IF EXISTS test'"
			REM Make our changes take effect
			call :runonvm !FULL_VM_NAME! "mysql -e 'FLUSH PRIVILEGES'"
		) ELSE (
			REM Run the full file, if the user wants interactivity
			call :runonvm !FULL_VM_NAME! "mysql_secure_installation"
		)
		
		REM We need to keep mariadb stopped, or it may cause errors
		call :runonvm !FULL_VM_NAME! "service mariadb stop"
	)
)


IF !INTERACTIVE! EQU 0 (
	REM Skips asking for the password and user information
	call :runonvm !FULL_VM_NAME! "adduser --gecos '' --disabled-password !OS_USER!"
) ELSE (
	call :runonvm !FULL_VM_NAME! "adduser !OS_USER!"
)

IF !runonvm! EQU 0 (
	REM This is dummy, but that's how you add an user to a group ...
	call :runonvm !FULL_VM_NAME! "adduser !OS_USER! sudo"
	
	wsl --manage !FULL_VM_NAME! --set-default-user !OS_USER!
) ELSE (
	echo ❌ Failed to create the user !OS_USER!
)

REM We don't need the VM running anymore
wsl --terminate !FULL_VM_NAME!

echo.
echo.
echo.

echo ✅ All done. Don't forget:

set "list=0"

set /a "list+=1"
echo !list!- The VM [7m !FULL_VM_NAME! [0m is OFF - run [7m wsl -d !FULL_VM_NAME! [0m to start it

IF !INTERACTIVE! EQU 0 (
	set /a "list+=1"
	echo !list!- Run [7m passwd !OS_USER! [0m as root, to change your user password
	echo You may need to run [7m wsl -d !FULL_VM_NAME! -u root --shell-type standard -- passwd !OS_USER! [0m
)

IF NOT [!PHP_VERSION!] EQU [] (
	set /a "list+=1"
	IF !PHP_XDEBUG_START_W_REQ! EQU yes (
		echo !list!- Xdebug is enabled on port [7m !PHP_XDEBUG_PORT! [0m
		echo You can view the configurations in:
	) ELSE (
		echo !list!- Xdebug can be enabled and configured in:
	)
	
	FOR %%t IN (!PHP_INI_TYPES!) DO (
		echo - !PHP_INI_ROOT!/%%t/php.ini
	)
	
	echo Look for the section [xdebug] at the end of the file
)

IF NOT [!APACHE_CONFIG_SITE!] EQU [] (
	call :site_in_hosts "!APACHE_DOMAIN!"
	
	IF [!site_in_hosts!] EQU [] (
		set /a "list+=1"
		echo !list!- Add the site [7m !APACHE_DOMAIN! [0m to [7m %systemRoot%\System32\drivers\etc\hosts [0m.
		echo Add these lines at the bottom of the hosts file:
		echo 127.0.0.1		!APACHE_DOMAIN!
		echo ^:^:1			!APACHE_DOMAIN!
	) ELSE (
		set /a "list+=1"
		echo !list!- The site [7m !APACHE_DOMAIN! [0m is accessible in these IPs: [7m !site_in_hosts! [0m
	)
)

IF EXIST "%USERPROFILE%\.ssh" (
	set /a "list+=1"
	echo !list!- Copy the [7m %USERPROFILE%\.ssh [0m folder to the [7m !OS_USER! [0m home folder
	echo After copying, run the command [7m chmod -R 700 ~/.ssh [0m
	echo ⚠️ If you do not copy, [7m git [0m will not be able to clone private repos
)

set /a "list+=1"
echo !list!- Confirm that everything is fine

exit /b 0






REM #
REM # ============================================
REM #




REM UI functions




:apache_config

REM DO NOT PUT setlocal EnableDelayedExpansion
REM doing so will prevent us from changing these globals

:apache_reset_ui
cls

echo [7m        Configure Apache2        [0m
echo.

IF NOT [!APACHE_TYPE!] EQU [] (
	echo Current type: [7m !APACHE_TYPE! [0m
) ELSE (
	echo Current type: [7m ^<none^> [0m
	echo ⚠️ The other fields won't have effect
)

echo [T] Change type
echo.

IF "!APACHE_DOMAIN!" EQU "localhost" (
	set "APACHE_DOMAIN="
	echo Domain name: [7m !APACHE_DOMAIN! [0m
	echo ❌ Domain name can't be localhost
) ELSE (
	echo Domain name: [7m !APACHE_DOMAIN! [0m
)

echo [D] Change domain name
echo.


REM Automatically set the root folder if the domain was set
IF NOT [!APACHE_DOMAIN!] EQU [] (
	IF [!APACHE_ROOT!] EQU [] (
		FOR /F "tokens=1 delims=." %%d IN ("!APACHE_DOMAIN!") DO (
			set "APACHE_ROOT=%%d"
		)
	)
)


IF [!APACHE_ROOT!] EQU [] (
	echo Website folder name: [7m  [0m
) ELSE (
	echo Website folder name: !APACHE_BASE_ROOT!/[7m !APACHE_ROOT! [0m
)


echo [F] Change folder name
echo.

IF "!APACHE_SSL!" EQU "1" (
	echo Use SSL^/TLS? [7m ✅ Yes [0m
) ELSE (
	echo Use SSL^/TLS? [7m ❌ No [0m
)
echo [S] Toggle yes/no

IF [!APACHE_DOMAIN!] EQU [] (
	IF [!APACHE_ROOT!] EQU [] (
		echo.
		echo ⚠️  Fill the domain and folder to automatically configure the local website
	)
)

echo.


choice /c:bsfdt /n /m "[B] Back"

IF ERRORLEVEL 5 (
	call :choice "Select the Apache2 type" APACHE "!APACHE_TYPE!" false
	set "APACHE_TYPE=!choice!"
	goto :apache_reset_ui
) ELSE IF ERRORLEVEL 4 (
	call :input "New domain name: " "!APACHE_DOMAIN!" true :validate_domain
	set "APACHE_DOMAIN=!input!"
	goto :apache_reset_ui
) ELSE IF ERRORLEVEL 3 (
	call :input "New folder name: !APACHE_BASE_ROOT!/" "!APACHE_ROOT!" true
	set "APACHE_ROOT=!input!"
	goto :apache_reset_ui
) ELSE IF ERRORLEVEL 2 (
	IF !APACHE_SSL! EQU 1 (
		set "APACHE_SSL=0"
	) ELSE (
		set "APACHE_SSL=1"
	)
	goto :apache_reset_ui
)


goto :eof



REM functions - validation




REM Validates a PHP version
REM %1 = current value
REM Returns 0 for invalid, 1 for valid
:validate_php_ver
setlocal EnableDelayedExpansion

set "value=%~1"

IF NOT [!value!] EQU [] (
	IF "!value!" EQU "." (
		echo ❌ Invalid version
		
		endlocal & set "validate_php_ver=0"
		goto :eof
	)
	
	FOR /F "tokens=1,2,* delims=." %%p IN ("!value!") DO (
		IF [%%p] EQU [] (
			echo ❌ Major version required ^(E.g.: !PHP_VERSION[7]!^)
			
			endlocal & set "validate_php_ver=0"
			goto :eof
		)
		
		IF [%%q] EQU [] (
			echo ❌ Minor version required ^(E.g.: !PHP_VERSION[7]!^)
			
			endlocal & set "validate_php_ver=0"
			goto :eof
		)
		
		IF NOT [%%r] EQU [] (
			echo ❌ Major and minor version only ^(E.g.: !PHP_VERSION[7]!^)
			
			endlocal & set "validate_php_ver=0"
			goto :eof
		)
	)
)

endlocal & set "validate_php_ver=1"
goto :eof






REM Validates a domain name, to make sure it can be used
REM %1 = current value
REM Returns 0 for invalid, 1 for valid
:validate_domain
setlocal EnableDelayedExpansion

set "value=%~1"

IF NOT [!value!] EQU [] (
	REM We test the blacklist first
	FOR %%x IN (!INVALID_DOMAINS!) DO (
		IF "!value!" EQU "%%x" (
			echo ❌ Domain cannot be %%x
			echo Any of these is not allowed: !INVALID_DOMAINS!
			
			endlocal & set "validate_domain=0"
			goto :eof
		)
	)
	
	REM We chunk it into an array and process later
	set "parts.length=0"
	FOR /F "tokens=1,2,* delims=." %%p IN ("!value!") DO (
		set /a "parts.length+=1"
		set "parts[!parts.length!]=%%p"
		
		
		IF NOT [%%q] EQU [] (
			set /a "parts.length+=1"
			set "parts[!parts.length!]=%%q"
		) ELSE (
			echo ❌ TLD is required - allowed: !VALID_DOMAIN_TLDS!
			
			endlocal & set "validate_domain=0"
			goto :eof
		)
		
		IF NOT [%%r] EQU [] (
			echo ❌ Sub-domains aren't allowed
			
			endlocal & set "validate_domain=0"
			goto :eof
		)
	)
	
	
	set "valid_tld=0"
	FOR %%t IN (!VALID_DOMAIN_TLDS!) DO (
		IF "!parts[2]!" EQU "%%t" (
			set "valid_tld=1"
		)
	)
	
	IF !valid_tld! EQU 0 (
		echo ❌ Bad TLD .!parts[2]! - allowed: !VALID_DOMAIN_TLDS!
		
		endlocal & set "validate_domain=0"
		goto :eof
	)
)

endlocal & set "validate_domain=1"
goto :eof






REM function - vm stuff



:vmexists
REM Checks if the VM name already exists
REM %1 = name of VM
REM returns 1 if exists, 0 if it doesn't
setlocal EnableDelayedExpansion

set "exists=0"
set "name=%~1"


wsl -d !name! --status >nul 2>nul

IF !ERRORLEVEL! EQU 0 (
	set "exists=1"
)

endlocal & set "vmexists=%exists%"
goto :eof





:runonvm
REM Runs the command in a specific VM, based on name
REM %1 = name of VM
REM %2 = command
REM returns the exit code
setlocal EnableDelayedExpansion

wsl -d %~1 --shell-type standard -- eval "%~2; exit $?"

set "error=%ERRORLEVEL%"

IF NOT !error! EQU 0 (
	echo ⚠️ Exit code: !error! for command %2
)

endlocal & set "runonvm=%error%"
goto :eof




REM functions - os checks




REM Check if the server exists in the hosts
REM %1 = server name
REM Returns all the IPs, separated by space
:site_in_hosts
SetLocal EnableDelayedExpansion

set "site=%~1"
set "ips="

FOR /F "tokens=1,* eol=#" %%i IN (%systemRoot%\System32\drivers\etc\hosts) DO (
	IF %%j EQU !site! (
		IF [!ips!] EQU [] (
			set "ips=%%i"
		) ELSE (
			set "ips=!ips! %%i"
		)
	)
)

endlocal & set "site_in_hosts=%ips%"
goto :eof



REM functions - input handling




:input
REM Receive input from STDIN
REM %1 = prompt
REM %2 = default value
REM %3 = 1 or empty - allow empty values
REM %4 = name of function for validation, where %1 is the current value
REM Returns a string
setlocal EnableDelayedExpansion

set "input=%~2"

call :bool "%~3" 1
set "allowempty=!bool!"

set "fn=%~4"
IF NOT [!fn!] EQU [] (
	REM Remove the : from the function name
	set "fn_name=!fn::=!"
	
	set "fn_label=:!fn_name!"
)

:input_loop


set "value=!input!"

set /p "value=%~1"


REM Run the validation function, if set
IF NOT [!fn_name!] EQU [] (
	
	call !fn_label! "!value!"
	
	set "error=%ERRORLEVEL%"
	set "fn_value=!%fn_name%!"
	
	REM If the "return" is empty, check error level
	IF [!fn_value!] EQU [] (
		REM 0 = good, 1 = bad
		IF !error! EQU 1 (
			goto :input_loop
		)
	) ELSE (
		REM Convert the return value of the function
		call :bool "!fn_value!" 1
		
		REM 0 = bad, 1 = good
		IF !bool! EQU 0 (
			goto :input_loop
		)
	)
)


IF [!value!] EQU [] (
	IF !allowempty! EQU 0 (
		set "value=%input%"
	)
)

set "input=!value!"

endlocal & set "input=%input%"
goto :eof





:choice
REM Lets you pick a value from a list, or a custom value, up to 9 values
REM %1 = title
REM %2 = name of the array
REM %3 = previous value
REM %4 = 1 or empty - allow custom values, anything else skips custom
REM %5 = function for validating custom values
setlocal EnableExtensions EnableDelayedExpansion

set "var=%~2"
set "choice=%~3"

IF [!%var%.length!] EQU [] (
	set "!%var%.length!=0"
)

IF [!%var%.length!] EQU [0] (
	endlocal & set "choice=%choice%"
	goto :eof
)


REM Convert to bool - empty is 1
call :bool "%~4" 1
set "allowcustom=!bool!"
set "validate_fn=%~5"
set "allowempty=0"


REM If no custom values are allowed and there's only 1 option, just return the previous value
If !allowcustom! EQU 0 (
	IF [!%var%.length!] EQU [1] (
		endlocal & set "choice=!%var%[1]!"
		goto :eof
	)
)


REM arrays start at 1
set "length=!%var%.length!"

REM Only allow up to 9 options
IF !length! GTR 9 (
	set "length=9"
)


set "options="

cls
set "title=%~1"
echo [7m        !title!        [0m
echo.

FOR /L %%i IN (1,1,!length!) DO (
	set "value=!%var%[%%i]!"
	set "output=!value!"
	
	IF [!output!] EQU [] (
		set "output=<none>"
		set "allowempty=1"
	)
	
	IF [!choice!] EQU [!value!] (
		echo [32m^>%%i[0m  !output!
	) ELSE (
		echo [%%i] !output!
	)
	
	set "options=!options!%%i"
)


set "options.length=!length!"

If !allowcustom! EQU 1 (
	echo [Z] Custom: [7m !choice! [0m
	set "options=!options!z"
	set /a "options.length+=1"
)

set /a "options.length+=1"
echo [C] Cancel

echo.

choice /c:!options!c /n /m "[ "

set "pick=%ERRORLEVEL%"

IF !pick! EQU !options.length! (
	endlocal & set "choice=%choice%"
	goto :eof
)

If !allowcustom! EQU 1 (
	set /a "customoption=!options.length!-1"
	
	IF !pick! EQU !customoption! (
		REM set /p "custom=Custom value: "
		
		call :input "Custom value: " "!choice!" !allowempty! !validate_fn!
		
		set "choice=!input!"
	) ELSE (
		set "choice=!%var%[%pick%]!"
	)
) ELSE (
	set "choice=!%var%[%pick%]!"
)


endlocal & set "choice=%choice%"
goto :eof





:bool
REM Returns 0 or 1, based on if a value is truthy or falsey
REM Returns 1 for: 1, true and TRUE
REM Returns 0 for: 0, false and FALSE
REM Returns the default value (0 or 1) for anything else
REM %1 = the value to parse
REM %2 = default value - must be 0 or 1, or returns 0
setlocal EnableDelayedExpansion

set "bool=%~1"

IF [!bool!] EQU [1] (
	set "bool=1"
) ELSE IF [!bool!] EQU [true] (
	set "bool=1"
) ELSE IF [!bool!] EQU [TRUE] (
	set "bool=1"
) ELSE IF [!bool!] EQU [0] (
	set "bool=0"
) ELSE IF [!bool!] EQU [false] (
	set "bool=0"
) ELSE IF [!bool!] EQU [FALSE] (
	set "bool=0"
) ELSE (
	set "default=%~2"

	IF NOT [!default!] EQU [1] (
		IF NOT [!default!] EQU [0] (
			set "default=0"
		)
	)
	
	set "bool=!default!"
)


endlocal & set "bool=%bool%"
goto :eof





REM functions for file and dir stuff



:getfile
REM selects a file
REM %1 = title
REM %2 = file types
REM %3 = skip "all types", if %1 is set
REM exit: 1 = cancelled
setlocal EnableDelayedExpansion

set "allfiles=All files (*.*)^| *.*"
set "types=!allfiles!"
set "title=%~1"

IF [!title!] EQU [] (
	set "title=Select a file"
)

IF NOT [%2] EQU [] (
	set "types=%~2"
	
	IF [%3] EQU [] (
		set "types=!types!^|!allfiles!"
	)
)

REM https://stackoverflow.com/a/50115044
REM fix for dialog not showing: https://stackoverflow.com/q/216710
set cmd=powershell -NoProfile -Noninteractive -NoLogo -command "&{[System.Reflection.Assembly]::LoadWithPartialName('System.windows.forms')|Out-Null; $F = New-Object System.Windows.Forms.OpenFileDialog; $F.ShowHelp = $true; $F.filter = '!types!'; $F.title = '!title!'; $F.ShowDialog()|Out-Null; $F.FileName}"

for /f "delims=" %%i in ('!cmd!') do (
	set "file=%%i"
)

IF "!file!" EQU "" (
	endlocal & set "getfile="
	exit /b 1
)

endlocal & set "getfile=%file%"
goto :eof



:getfolder
REM fetches a folder path
REM %1 = title
REM exit: 1 = cancelled
setlocal EnableDelayedExpansion

set txt="Please choose a folder."
IF NOT [%1] EQU [] (
	set "txt=%~1"
)

REM executes the folder dialog - https://stackoverflow.com/a/15885133
set "cmd="(new-object -COM 'Shell.Application').BrowseForFolder(0,'%txt%',0,0).self.path""
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Noninteractive -NoLogo %cmd%`) do (
	set "folder=%%I"
)

IF "!folder!" EQU "" (
	endlocal & set "getfolder="
	exit /b 1
)

endlocal & set "getfolder=%folder%"
goto :eof
