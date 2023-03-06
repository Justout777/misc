# Company X
This is a project where i'm trying to simulate a company that uses the Azure landing Zone provided by Microsoft (https://github.com/Azure/ALZ-Bicep). Using this method i can continously expand the project like in a real world scenario by adding more and more solutions.

I also used the resource modules provided by Microsoft: https://github.com/Azure/ResourceModules. Note that the modules are not included in this repo.

## Azure Landing Zone
The first one to deploy is the main.bicep file in 'Main_AzureLandingZone' which contains (almost) everything for the azure landing zone that microsoft provides. This is my starting point and foundation of the infrastucture. 

In the same folder is also a seperate bicep file where the firewall rules can be managed. 

## Solution 1: VM with IIS

Simple solution where i create a spoke network that peers with the hub. Here there will be a VM deployed with IIS. Using the firewall bicep file i can create the firewall rules and DNAT to access the website through the firewall. Next step will be implementing an application gateway that forwards the request to the firewall and back to the VM.

## Solution 2: TBD

kubernetes maybe?

