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

# Prerequisites
# Check if az CLI is installed
if ! command -v az &> /dev/null
then
    echo "az CLI could not be found. Please install it first."
    exit
fi
# check if docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found. Please install it first."
    exit
fi
# check if kubectl is installed
if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found. Please install it first."
    echo "run: az aks install-cli"
    exit
fi
# check if helm is installed
if ! command -v helm &> /dev/null
then
    echo "Helm could not be found. Please install it first."
    exit
fi

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

# Az Login
az login --use-device-code

# Creation Commands
echo "Creating AKS Cluster: $AKS_CLUSTER_NAME"
az group create --name $AKS_CLUSTER_RESOURCE_GROUP_NAME --location $REGION
az aks create --resource-group $AKS_CLUSTER_RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --node-count 1 --generate-ssh-keys --nodepool-name $NODEPOOL_NAME
echo "AKS Cluster: $AKS_CLUSTER_NAME created successfully."

# Pause and prompt user to continue
read -p "Configuration begins...Press 'y' to continue: " -n 1 -r
echo    
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Aborting script."
    exit 1
fi

# Enabled User Assigned Managed Identity on the Nodepools
echo "Enabling User Assigned Managed Identity on the Nodepools for Cluster: $AKS_CLUSTER_NAME"
az aks update --resource-group $AKS_CLUSTER_RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --enable-managed-identity
# recycle nodes to accept system Managed identity security scheme
echo "Recycling the Nodepools for Cluster: $AKS_CLUSTER_NAME"
az aks nodepool upgrade --resource-group $AKS_CLUSTER_RESOURCE_GROUP_NAME --cluster-name $AKS_CLUSTER_NAME --name $NODEPOOL_NAME --node-image-only

# Add the Blob CSI Driver
echo "Adding Blob CSI Drivers to the cluster: $AKS_CLUSTER_NAME"
az aks update --enable-blob-driver --name $AKS_CLUSTER_NAME --resource-group $AKS_CLUSTER_RESOURCE_GROUP_NAME

# Get the credentials to login to the cluster and SSH etc...
echo "Getting Cluster Credentials..."
az aks get-credentials --resource-group $AKS_CLUSTER_RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME

echo "Getting MSI Client ID..."
export KUBELET_USER_ASSIGNED_IDENTITY_CLIEND_ID=$(az aks show --name $AKS_CLUSTER_NAME --resource-group $AKS_CLUSTER_RESOURCE_GROUP_NAME --query identityProfile.kubeletidentity.clientId --output tsv)
echo "Getting NodePool Resource Group Name..."
export NODEPOOL_RESOURCE_GROUP_NAME=$(az aks show --name $AKS_CLUSTER_NAME --resource-group $AKS_CLUSTER_RESOURCE_GROUP_NAME --query nodeResourceGroup -o tsv)

# Create the storage account to mount the volume
echo "Creating Storage Account: $WORKLOAD_STORAGE_ACCOUNT_NAME in Resource Group: $NODEPOOL_RESOURCE_GROUP_NAME"
az storage account create -n $WORKLOAD_STORAGE_ACCOUNT_NAME -g $NODEPOOL_RESOURCE_GROUP_NAME -l $REGION --sku Standard_LRS
# Create the container to mount the volume using PV Claim
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $WORKLOAD_STORAGE_ACCOUNT_NAME -g $NODEPOOL_RESOURCE_GROUP_NAME -o tsv) 
echo "Creating Container: $WORKLOAD_CONTAINER_NAME in Storage Account: $WORKLOAD_STORAGE_ACCOUNT_NAME"
az storage container create -n $WORKLOAD_CONTAINER_NAME --connection-string $AZURE_STORAGE_CONNECTION_STRING

# Create RBAC Permissions
echo "Creating RBAC Permissions for Storage Account: $WORKLOAD_STORAGE_ACCOUNT_NAME"
export ASSIGNMENT_SCOPE=$(az storage account show -n $WORKLOAD_STORAGE_ACCOUNT_NAME -g $NODEPOOL_RESOURCE_GROUP_NAME --query id -o tsv)
az role assignment create --assignee $KUBELET_USER_ASSIGNED_IDENTITY_CLIEND_ID --role "Storage Blob Data Contributor" --scope $ASSIGNMENT_SCOPE

# create the ACR
echo "Creating ACR: $ACR_NAME"
az acr create --resource-group $NODEPOOL_RESOURCE_GROUP_NAME --name $ACR_NAME --sku Premium --location $REGION
# Create the ACR Role Assignment
echo "Creating ACR Role Assignment for ACR: $ACR_NAME"
export ACR_ID=$(az acr show --name $ACR_NAME --resource-group $NODEPOOL_RESOURCE_GROUP_NAME --query id -o tsv)
az role assignment create --assignee $KUBELET_USER_ASSIGNED_IDENTITY_CLIEND_ID --role "AcrPull" --scope $ACR_ID

# Docker Commands to Build and Push the Image
echo "Building and Pushing Docker Image..."
docker build -t $DOCKER_IMAGE_NAME .
docker tag $DOCKER_IMAGE_NAME:latest $ACR_NAME.azurecr.io/$ACR_REPO_NAME/$DOCKER_IMAGE_NAME:latest
az acr login --name $ACR_NAME
docker push $ACR_NAME.azurecr.io/$ACR_REPO_NAME/$DOCKER_IMAGE_NAME:latest --quiet
wait

# Helm Commands to Install the Workload (Only Done Once - Already done for Repo)
# helm create aks-lab
# helm repo add stable https://charts.helm.sh/stable
# helm repo update

helm install aks-lab ./aks-lab \
  --set aksLab.resourceGroupName=$AKS_CLUSTER_RESOURCE_GROUP_NAME \
  --set aksLab.region=$REGION \
  --set aksLab.clusterName=$AKS_CLUSTER_NAME \
  --set aksLab.storageAccountName=$WORKLOAD_STORAGE_ACCOUNT_NAME \
  --set aksLab.containerName=$WORKLOAD_CONTAINER_NAME \
  --set aksLab.azureStorageIdentityClientID=$KUBELET_USER_ASSIGNED_IDENTITY_CLIEND_ID
