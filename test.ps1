import csv
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.postgresql import PostgreSQLManagementClient

def get_credentials():
    # This will use the default credentials from your local machine
    return DefaultAzureCredential()

def get_resource_client(credentials, subscription_id):
    return ResourceManagementClient(credentials, subscription_id)

def get_postgresql_client(credentials, subscription_id):
    return PostgreSQLManagementClient(credentials, subscription_id)

def get_subscriptions_and_resource_groups_from_csv(file_path):
    with open(file_path, 'r') as file:
        reader = csv.DictReader(file)
        return list(reader)

def get_postgresql_servers(postgresql_client, resource_group=None):
    if resource_group:
        return postgresql_client.servers.list_by_resource_group(resource_group)
    else:
        return postgresql_client.servers.list()

def write_to_csv(servers, file_path):
    with open(file_path, 'w', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=['Server Name', 'Subscription', 'Resource Group', 'Location', 'Type', 'SKU'])
        writer.writeheader()
        for server in servers:
            writer.writerow({
                'Server Name': server.name,
                'Subscription': server.id.split('/')[2],
                'Resource Group': server.id.split('/')[4],
                'Location': server.location,
                'Type': server.type,
                'SKU': server.sku.name
            })

def main():
    credentials = get_credentials()
    subscriptions_and_resource_groups = get_subscriptions_and_resource_groups_from_csv('subscriptions.csv')
    servers = []

    for item in subscriptions_and_resource_groups:
        subscription_id = item['SubscriptionName']
        resource_group = item.get('ResourceGroupName')

        postgresql_client = get_postgresql_client(credentials, subscription_id)
        servers.extend(get_postgresql_servers(postgresql_client, resource_group))

    write_to_csv(servers, 'output.csv')

if __name__ == "__main__":
    main()
