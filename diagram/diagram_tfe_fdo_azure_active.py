from diagrams import Cluster, Diagram
from diagrams.onprem.compute import Server


from diagrams.azure.compute import VMLinux
from diagrams.azure.compute import VMScaleSet
from diagrams.azure.database import DatabaseForPostgresqlServers
from diagrams.azure.database import CacheForRedis
from diagrams.azure.storage import BlobStorage
from diagrams.azure.network import LoadBalancers



# Variables
title = "Virtual Network with 1 public subnet for the client and 3 private subnets for PostgreSQL, Redis and TFE instance requirement."
outformat = "png"
filename = "diagram_tfe_fdo_azure_active-active"
direction = "TB"


with Diagram(
    name=title,
    direction=direction,
    filename=filename,
    outformat=outformat,
) as diag:
    # Non Clustered
    user = Server("user")

    # Cluster 
    with Cluster("Azure"):
        bucket_tfe = BlobStorage("TFE bucket")
        lb = LoadBalancers("Load balancer")
        with Cluster("vpc"):
            with Cluster("Availability Zone: \n\n  "):
                # Subcluster 
                with Cluster("subnet_public1"):
                    ec2_client_machine = VMLinux("Client_machine")
                with Cluster("subnet_private1"):
                     postgresql = DatabaseForPostgresqlServers("RDS Instance")
                with Cluster("subnet_private2"):
                     ec2_tfe_scale_set = VMScaleSet("TFE Scale Set")
                with Cluster("subnet_private3"):
                     redis = CacheForRedis("Redis Instance")
                     
               
    # Diagram

    user >> [ec2_client_machine,
             lb]
   
    lb >> [ec2_tfe_scale_set]

    ec2_tfe_scale_set >> [postgresql,
                       bucket_tfe,
                       redis]

diag
