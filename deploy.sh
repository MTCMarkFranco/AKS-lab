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
az aks update --resource-group "myAKSResourceGroup0472af" --name "myAKSCluster0472af" --enable-managed-identity
# recycle nodes to accept system Managed identity security scheme
az aks nodepool upgrade --resource-group "myAKSResourceGroup0472af" --name "myAKSCluster0472af" --name nodepool1 --node-image-only

# Persistant Volume Storage Creation
# Get the node resource group name for reference later
export NODEPOOL_RESOURCE_GROUP_NAME=$(az aks show --resource-group myAKSResourceGroup0472af --name myAKSCluster0472af --query nodeResourceGroup -o tsv)

# Create the storage account to mount the volume
az storage account create -n sadatavolveaccount -g $NODEPOOL_RESOURCE_GROUP_NAME -l canadacentral --sku Standard_LRS

# create the SHare to mount the volume
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n sadatavolveaccount -g MC_myAKSResourceGroup0472af_myAKSCluster0472af_canadacentral -o tsv) 
az storage share create -n datavolve-container --connection-string $AZURE_STORAGE_CONNECTION_STRING

# Get the system Assigned Identity Client ID
az aks show --name myAKSCluster0472af --resource-group myAKSResourceGroup0472af --query "identityProfile.kubeletidentity.clientId" -o tsv

# [IMPORTANT] Assign the client ID to inside the azure-storage-csi.yaml and azurefiles-pv.yaml files

# [IMPORTANT] USE THE PORTAL TO DO THIS FOR NOW: In the storage account Add the system assigned identity as the Storage file Data Contrubutor

# Create the persistant Volume
kubectl create -f azure-storage-csi.yaml

# Set Volume Properties and apply the volume
kubectl apply -f azurefiles-pv.yaml

# [IMPORTANT] Update Storage account fileshare to include folder structure and config / xml /Data Files

# [IMPORTANT] Update the datavolve-deployment.yaml to use the volume
# apply the deployment
kubectl apply -f datavolve-deployment.yaml