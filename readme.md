# AKS Job Container Deployment

This project deploys an Azure Kubernetes Service (AKS) Job Container that mounts a container in an Azure Storage Account. The container writes files to the mounted storage and completes the job upon finishing the file operations. The storage account container is mounted using the Cluster User Assigned Managed Identity (UAMI) assigned to the default Nodepool, which has been granted the "Storage Blob Data Contributor" role using RBAC IAM.

## Prerequisites

Before running the deployment script, ensure you have the following installed:
- Azure CLI (`az`)
- Docker
- kubectl (can be installed via `az aks install-cli`)

## Deployment

The `deploy.sh` script automates the deployment of the AKS cluster and all necessary resources. It performs the following steps:
1. Creates an AKS cluster.
2. Enables User Assigned Managed Identity on the Nodepools.
3. Adds the Blob CSI Driver to the cluster.
4. Creates a storage account and container.
5. Assigns RBAC permissions to the storage account.
6. Creates an Azure Container Registry (ACR) and assigns the necessary roles.
7. Creates a ConfigMap to store the MSI Client ID.
8. Creates a Persistent Volume (PV) and Persistent Volume Claim (PVC).
9. Builds and pushes the Docker image to the ACR.
10. Deploys the workload job to the AKS cluster.

To deploy the cluster and resources, run:
```bash
./deploy.sh
```

## Project Structure

- `workload-1-deploy.yaml`: Defines the Kubernetes Job for the workload.
- `Dockerfile`: Specifies the Docker image for the workload container.
- `azure-storage-pvc.yaml`: Defines the Persistent Volume Claim.
- `azure-storage-pv.yaml`: Defines the Persistent Volume.
- `deploy.sh`: Shell script to deploy the AKS cluster and resources.

## Summary

This project demonstrates how to deploy an AKS Job Container that interacts with an Azure Storage Account using a User Assigned Managed Identity. The deployment script simplifies the process by automating the creation and configuration of all necessary resources.