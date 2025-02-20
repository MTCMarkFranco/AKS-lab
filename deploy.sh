export RANDOM_ID="$(openssl rand -hex 3)"
export MY_RESOURCE_GROUP_NAME="myAKSResourceGroup$RANDOM_ID"
export REGION="canadacentral"
export MY_AKS_CLUSTER_NAME="myAKSCluster$RANDOM_ID"
export MY_DNS_LABEL="mydnslabel$RANDOM_ID"

# Creation Commands
az group create --name $MY_RESOURCE_GROUP_NAME --location $REGION
az aks create --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME --node-count 1 --generate-ssh-keys
az aks update --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME --enable-managed-identity


# **** Specific commands for the lab ****
# Enable the managed identity
az aks get-credentials --resource-group myAKSResourceGroup0472af --name myAKSCluster0472af

az aks update --resource-group "myAKSResourceGroup0472af" --name "myAKSCluster0472af" --enable-managed-identity
# recycle nodes to accept system Managed identity security scheme
az aks nodepool upgrade --resource-group "myAKSResourceGroup0472af" --cluster-name "myAKSCluster0472af" --name nodepool1 --node-image-only

# add the Blob CSI Driver
az aks update --enable-blob-driver --name myAKSCluster0472af --resource-group myAKSResourceGroup0472af

# Persistant Volume Storage Creation
# Get the node resource group name for reference later
export NODEPOOL_RESOURCE_GROUP_NAME=$(az aks show --resource-group myAKSResourceGroup0472af --name myAKSCluster0472af --query nodeResourceGroup -o tsv)

# Create the storage account to mount the volume
az storage account create -n sadatavolveaccount -g $NODEPOOL_RESOURCE_GROUP_NAME -l canadacentral --sku Standard_LRS

# create the SHare to mount the volume
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n sadatavolveaccount -g MC_myAKSResourceGroup0472af_myAKSCluster0472af_canadacentral -o tsv) 
az storage share create -n datavolve-container --connection-string $AZURE_STORAGE_CONNECTION_STRING

# Get the principal ID for a system-assigned managed identity.
export KUBELET_USER_ASSIGNED_IDENTITY_CLIEND_ID=$(az aks show --name myAKSCluster0472af --resource-group myAKSResourceGroup0472af --query identityProfile.kubeletidentity.clientId --output tsv)
# 261ac719-91e0-438d-aebc-7e5687c074fb
# az role assignment create --assignee $KUBELET_USER_ASSIGNED_IDENTITY_CLIEND_ID --role "Network Contributor" --scope "/subscriptions/28d10200-70b0-476c-b004-c6ae29265897/resourceGroups/MC_myAKSResourceGroup0472af_myAKSCluster0472af_canadacentral/providers/Microsoft.Storage/storageAccounts/sadatavolveaccount"
az role assignment create --assignee $KUBELET_USER_ASSIGNED_IDENTITY_CLIEND_ID --role "Storage Blob Data Contributor" --scope "/subscriptions/28d10200-70b0-476c-b004-c6ae29265897/resourceGroups/MC_myAKSResourceGroup0472af_myAKSCluster0472af_canadacentral/providers/Microsoft.Storage/storageAccounts/sadatavolveaccount" --subscription "28d10200-70b0-476c-b004-c6ae29265897"
az role assignment create --assignee $KUBELET_USER_ASSIGNED_IDENTITY_CLIEND_ID --role "Storage File Data SMB Share Contributor" --scope "/subscriptions/28d10200-70b0-476c-b004-c6ae29265897/resourceGroups/MC_myAKSResourceGroup0472af_myAKSCluster0472af_canadacentral/providers/Microsoft.Storage/storageAccounts/sadatavolveaccount" --subscription "28d10200-70b0-476c-b004-c6ae29265897"

# Create the persistant Volume
kubectl create -f azure-storage-pv.yaml

# Set Volume Properties and apply the volume
kubectl apply -f azure-storage-pvc.yaml

# [IMPORTANT] Update Storage account fileshare to include folder structure and config / xml /Data Files

# [IMPORTANT] Update the datavolve-deployment.yaml to use the volume
# apply the deployment
kubectl apply -f datavolve-deployment.yaml


#restart nodes
az vm restart --name aks-nodepool1-23655914-vmss000000 --resource-group MC_myAKSResourceGroup0472af_myAKSCluster0472af_canadacentral




# temp
# Create the storage account to mount the volume
az storage account create -n sadatavolveaccount3 -g myAKSResourceGroup0472af -l canadacentral --sku Standard_LRS

# create the SHare to mount the volume
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n sadatavolveaccount3 -g myAKSResourceGroup0472af -o tsv) 
az storage share create -n datavolve-container --connection-string $AZURE_STORAGE_CONNECTION_STRING



#TODO: Move away from the System Managed Identity and try at the POD level here: https://learn.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity

#  If pod level droesn;t work with storageclass, then go back to user manmaged idetity

mount -t cifs //sadatavolveaccount.file.core.windows.net/datavolve-container /mnt/datavolve-container -o dir_mode=0777,file_mode=0777,uid=0,gid=0,mfsymlinks,cache=strict,nosharesock,nobrl,actimeo=30,vers=3.0
mount -t cifs -o dir_mode=0777,file_mode=0777,uid=0,gid=0,mfsymlinks,cache=strict,nosharesock,nobrl,actimeo=30,vers=3.0 //sadatavolveaccount.file.core.windows.net/datavolve-container /mnt/datavolve-container