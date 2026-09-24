if (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue) {
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}
