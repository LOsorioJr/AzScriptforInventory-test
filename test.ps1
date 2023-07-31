import csv
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.rdbms import postgresql
from azure.mgmt.subscription import SubscriptionClient
from tqdm import tqdm

def get_credentials():
    return DefaultAzureCredential()

def get_subscription_id(credentials, subscription_name):
    subscription_client = SubscriptionClient(credentials)
    subscriptions = subscription_client.subscriptions.list()
    for subscription in subscriptions:
        if subscription.display_name == subscription_name:
            return subscription.subscription_id
    return None

def get_postgresql_client(credentials, subscription_id):
    return postgresql.PostgreSQLManagementClient(credentials, subscription_id)

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

def write_not_found_to_csv(not_found, file_path):
    with open(file_path, 'w', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=['SubscriptionName', 'ResourceGroupName'])
        writer.writeheader()
        writer.writerows(not_found)

def main():
    credentials = get_credentials()
    subscriptions_and_resource_groups = get_subscriptions_and_resource_groups_from_csv('subscriptions.csv')
    servers = []
    not_found = []

    for item in tqdm(subscriptions_and_resource_groups, desc="Processing subscriptions"):
        subscription_name = item['SubscriptionName']
        subscription_id = get_subscription_id(credentials, subscription_name)
        if subscription_id is None:
            not_found.append(item)
            continue

        resource_group = item.get('ResourceGroupName')

        try:
            postgresql_client = get_postgresql_client(credentials, subscription_id)
            servers.extend(get_postgresql_servers(postgresql_client, resource_group))
        except Exception as e:
            print(f"Error while processing subscription {subscription_name} and resource group {resource_group}: {e}")
            not_found.append(item)

    write_to_csv(servers, 'output.csv')
    write_not_found_to_csv(not_found, 'not_found.csv')

if __name__ == "__main__":
    main()
