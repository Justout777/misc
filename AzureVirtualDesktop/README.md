# Deploy Azure virtual Desktop AAD-joined multi-Session with custom image

This project aims to deploy an Azure virtual desktop environment where the VMs are Azure AD Joined and build from a custom image that is stored in a Compute Gallery.

It is seperated in three deployments (pipelines) because they have sort of different lifecycles. The intention is that the compute gallery (1_AVD-Image) is a shared resource and could be used by other solutions. The AVD infrastructure (2_AVD-Infra) is where the infrastructure for this specific solution is build. The sessionhosts (3_AVD-VM) are intended to be re-created every month using the latest image which has the latest windows and appplication patches. 

Summary of what is does:

**1_AVD-Image**

- Create User-assigned identity
- Create custom role for compute gallery actions
- Assigns user-assigned identity to custom role
- Create storageaccount with blob container
- Assigns blob read access to user-assigned identity
- Create compute gallery and image definition

**2_AVD-Infra**

- Create vnet
- Create hostpool
- Create Application Group
- Create workspace
- Create Image template

**3_AVD-VM**

- Assign group to VM User login Role (the security group with users that needs access)
- Create Virtual Machines
- Join to AzureAD
- Add VMs to hostpool (registration token is retreived in the pipeline and passed as argument)
- Create applications in the application group

The solution still needs the automation to re-build the image using the image template and also the automation to re-create the VMs, but this is outside my scope for this solution. Using azure automation with some logic in the pipeline for the VMs could automate this.

Also some cleanup and making use of more modules and conditions would be nice :)

Note: The code is as-is and never been used in production environment and is just for my own entertaining purposes. 
