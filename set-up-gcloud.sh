gcloud init;

# Create a custom VPC network
gcloud compute networks create my-lb-network --subnet-mode=custom;

# Create subnet
gcloud compute networks subnets create my-subnet \
  --network=my-lb-network \
  --range=10.1.10.0/24 \
  --region=southamerica-east1;

# Reserve the IP addresses
gcloud compute addresses create my-lb-ipv4 \
  --ip-version=IPV4 \
  --global;

# Create firewall rule to allow healthchecks and incoming traffic
gcloud compute firewall-rules create my-fw-allow-health-and-proxy \
  --network=my-lb-network \
  --action=allow \
  --direction=ingress \
  --target-tags=allow-hc-and-proxy \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --rules=tcp:80,tcp:443,tcp:3000;

# Create firewall rule to allow SSH 
gcloud compute firewall-rules create my-fw-allow-ssh \
  --network=my-lb-network \
  --action=allow \
  --direction=ingress \
  --target-tags=allow-ssh \
  --rules=tcp:22;
# Create instance template
gcloud compute instance-templates create-with-container my-first-template \
  --custom-cpu=1 \
  --custom-memory=2GB \
  --boot-disk-size=20GB \
  --container-env-file=secrets.dec \
  --region=southamerica-east1 \
  --subnet=my-subnet \
  --tags=allow-hc-and-proxy,allow-ssh \
  --container-image gcr.io/my-project-id/my-image-name;

# Create the managed instance group
gcloud compute instance-groups managed create my-mig \
  --base-instance-name my-instance \
  --size 3 \
  --template my-first-template \
  --region southamerica-east1;

# Create port forwarding
gcloud compute instance-groups managed set-named-ports my-mig \
  --named-ports port3000:3000 \
  --region southamerica-east1;

