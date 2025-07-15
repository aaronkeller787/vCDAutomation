# Cloud Director Onboarding Automation:
A VMware Cloud Director automation project written in Powershell.

## Description:
A robust PowerShell-based automation tool to fully provision new customer environments within VMware Cloud Director. The script automated the creation of organizations, Virtual Data Centers (vDCs), Edge Gateways, user accounts, and internal metadata tagging for streamlined tracking and support.

Prior to creation, onboarding would take anywhere from 1-2 hours depending on the complexity of the setup. The script got this time down to ~5 minutes.

## Tools:
**PowerShell:** Version 5.1 \
**PowerCLI:** Version 13.1.0 \
**VMware Cloud Director API:** Version 38.1 & 39.0 \
**NSX-T API Version:** 4.1.0.2

## How it Works:
This PowerShell-based automation tool provisions complete customer environments in VMware Cloud Director by interacting with the vCD REST API and PowerCLI. It eliminates the need for manual provisioning tasks and ensures consistency across deployments.

### Workflow Steps:

#### 1. Authenticate with Cloud Director API
 - Uses passed in credentials to authenticate against the vCD API endpoint

#### 2. Create the customer Organization
 - Calls the Org creation API endpoint and sets default Org properties (e.g user limits, quotas).

#### 3. Provision Virtual Data Center (vDC)
 - Selects the appropriate provider VDC and creates a new tenant vDC with specified compute/storage policies.

#### 4. Deploy Edge Gateway
 - Automates the creation of the Edge Gateway (NSX-T backed)

#### 5. Create Initial Users
 - Adds tenant user with the Org Admin role assigned, and enables the user for login. Password is auto-generated during script execution

#### 6. Tag with Metadata
 - Applies standardized metadata to Org and vDC resources (e.g., customer ID, creation date, engineer initials) for internal tracking.

#### 7. Output & Logging
 - Outputs success/failure results and optionally logs all API responses for auditing or troubleshooting.



## Supporting Documentation:
[VMware/Broadcom API Documentation](https://techdocs.broadcom.com/us/en/vmware-cis/cloud-director/vmware-cloud-director/10-5/-vcloud-api-programming-guide-for-service-providers-10-5.html)
