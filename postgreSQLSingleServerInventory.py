import argparse
import logging
import pandas as pd
from typing import List, Tuple, Dict, Any
from azure.identity import DefaultAzureCredential
from azure.mgmt.resourcegraph import ResourceGraphClient
from azure.mgmt.subscription import SubscriptionClient

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

def get_subscription_ids(batch: List[Dict[str, str]], sub_client) -> Tuple[
    List[Tuple[str, str]], List[str], List[str]]:
    subscription_ids = []
    not_found_subs = []
    invalid_subs = []
    for row in batch:
        sub_id = get_subscription_id(sub_client, row['SubscriptionName'])
        if sub_id is None:
            not_found_subs.append(row['SubscriptionName'])
        elif not is_valid_guid(sub_id):
            invalid_subs.append(row['SubscriptionName'])
        else:
            subscription_ids.append((sub_id, row['ResourceGroupName']))
    return subscription_ids, not_found_subs, invalid_subs

def get_postgresql_servers(client, subscription_id: str) -> Any:
    """
    Retrieves PostgreSQL servers for a given subscription ID.
    """
    query = ("Resources | where type =~ 'Microsoft.DBforPostgreSQL/servers' |"
             " project subscriptionId, name, resourceGroup, location, sku")
    return client.resources(query, [subscription_id])

def main(args: argparse.Namespace) -> None:
    df = pd.read_csv(args.input_file)
    subscription_data = df[['SubscriptionName', 'ResourceGroupName']].to_dict('records')

    credential = DefaultAzureCredential()
    resource_graph_client = ResourceGraphClient(credential)
    sub_client = SubscriptionClient(credential)

    output = []
    for batch in prepare_batches(subscription_data, args.batch_size):
        subscription_ids, not_found_subs, invalid_subs = get_subscription_ids(
            batch, sub_client)
        save_subscriptions(args.not_found_file, not_found_subs)
        save_subscriptions(args.invalid_file, invalid_subs)

        # Use the resource_graph_client to get PostgreSQL servers for each subscription ID
        for sub_id, resource_group in subscription_ids:
            servers = get_postgresql_servers(resource_graph_client, sub_id,
                                             resource_group)
            output.append(servers)
    print(output)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process Azure subscriptions.')
    parser.add_argument('--input', help='Input CSV file', default="subscriptions.csv")
    parser.add_argument('--batch_size', type=int, help='Batch size', default=500)
    parser.add_argument('--not_found_file', help='Output file for not found subscriptions', default='not_found_subscriptions.csv')
    parser.add_argument('--invalid_file', help='Output file for invalid subscriptions', default='invalid_subscriptions.csv')

    args = parser.parse_args()

    main(args)
