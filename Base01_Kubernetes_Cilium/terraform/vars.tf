variable "ssh_user" {
    default = "<user_name>"
}

variable "ssh_password" {
    default = "<password>"
}

variable "pm_user" {
    # Remember to include realm in username - user@realm
    default = "root@pam"
}

variable "pm_password" {
    # password for root@pam
    default = "<password>"
}

variable "pm_api_token_id" {
    # api token id is in the form of: <username>@pam!<tokenId>
    default = "root@pam!terraform"
} 

variable "pm_api_token_secret" {
    # Note: The api secret token will on ly be shown once when the token is created, make sure to save it.
    # this is the full secret wrapped in quotes:
    default = "<token_secret>"
}

variable "pm_api_url" {
    # proxmox cluster api url
    default = "https://{proxmox_ip}:8006/api2/json"
}