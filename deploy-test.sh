# Initialization
export AKS_CLUSTER_RESOURCE_GROUP_NAME="AKS-Lab-ResourceGroup"
export REGION="canadacentral"
export AKS_CLUSTER_NAME="AKSLabCluster"
export NODEPOOL_NAME="wrkld1pool"
export WORKLOAD_STORAGE_ACCOUNT_NAME="saworkload1account"
export WORKLOAD_CONTAINER_NAME="workload-1-container"
export ACR_NAME="acrakslabworkload1"
export ACR_REPO_NAME="workload1repo"
export DOCKER_IMAGE_NAME="workload-1-image"

# Display starting configurations
echo "Starting Settings:"
echo "Resource Group Name: $AKS_CLUSTER_RESOURCE_GROUP_NAME"
echo "Region: $REGION"
echo "AKS Cluster Name: $AKS_CLUSTER_NAME"
echo "Default Node Pool Name: $NODEPOOL_NAME"
echo "Workload Storage Account Name: $WORKLOAD_STORAGE_ACCOUNT_NAME"
echo "Workload Container Name: $WORKLOAD_CONTAINER_NAME"
echo "Azure Container Registry Name: $ACR_NAME"
echo ACR Repo Name: $ACR_REPO_NAME
echo "Docker Image Name: $DOCKER_IMAGE_NAME"
echo "----------------------------------------"

echo "Getting MSI Client ID..."
export KUBELET_USER_ASSIGNED_IDENTITY_CLIEND_ID=$(az aks show --name $AKS_CLUSTER_NAME --resource-group $AKS_CLUSTER_RESOURCE_GROUP_NAME --query identityProfile.kubeletidentity.clientId --output tsv)
echo "Getting NodePool Resource Group Name..."
export NODEPOOL_RESOURCE_GROUP_NAME=$(az aks show --name $AKS_CLUSTER_NAME --resource-group $AKS_CLUSTER_RESOURCE_GROUP_NAME --query nodeResourceGroup -o tsv)


helm template aks-lab ./aks-lab \
  --set aksLab.resourceGroupName=$AKS_CLUSTER_RESOURCE_GROUP_NAME \
  --set aksLab.region=$REGION \
  --set aksLab.clusterName=$AKS_CLUSTER_NAME \
  --set aksLab.storageAccountName=$WORKLOAD_STORAGE_ACCOUNT_NAME \
  --set aksLab.containerName=$WORKLOAD_CONTAINER_NAME \
  --set aksLab.azureStorageIdentityClientID=$KUBELET_USER_ASSIGNED_IDENTITY_CLIEND_ID