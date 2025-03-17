terraform { 
  cloud { 
    hostname = "tfe21.aws.munnep.com" 
    organization = "test" 

    workspaces { 
      name = "test" 
    } 
  } 
}

resource "terraform_data" "test" {}