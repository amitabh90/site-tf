environment        = "prod"
name_prefix        = "site"
subscription_id    = "c785c74c-7bd9-4afa-ac0a-c5d7912e2fda"
location           = "centralus"
vnet_address_space = ["10.173.0.0/24"]

subnets = {
  front = {
    name              = "front-subnet"
    address_prefix    = "10.173.0.0/27"
    service_endpoints = []
  }
  app = {
    name              = "app-subnet"
    address_prefix    = "10.173.0.32/27"
    service_endpoints = ["Microsoft.Web", "Microsoft.Storage"]
  }
  database = {
    name              = "database-subnet"
    address_prefix    = "10.173.0.64/27"
    service_endpoints = ["Microsoft.Sql"]
  }
}

extra_tags = {
  environment = "prod"
  lifetime    = "permanent"
  owner       = "Daniel&Chris"

}

app_subnet_cidr = ""
