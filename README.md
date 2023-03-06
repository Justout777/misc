# Introduction
Welcome to my public repo. This repo is used to show and share my code. I do this for learning and entertainment purposes and is mainly focused on Bicep. Feel free to use/copy/whatever but please use with causion ;)


## AzureVirtualDesktop
This solution deploys an azure virtual desktop using a custom image (Compute gallery and VM Image builder included) and joins it to Azure AD. The VM builder uses a user-assigned identity that has access to the compute gallery to retreive the script that customizes the image. 

DevOps pipelines included :)

## Company X
New project that is focused on using the Azure landing zone provided by Microsoft and the provided resource modules. Goal is to use the landing zone as starting point and keep adding new things to it. Great way to simulate real-world environments where new solution are being added along the way.

## MultiTierApp
This bicep deploys a zone redundant multi-tier app using a VMSS as the web-tier and managed instance as data-tier. It is isolated using NSGs and the frontend is loadbalanced by the application gateway. Objective for this project is purely learning this kind of architecture and deploy it with bicep. There is nothing configured on the application layer. 
