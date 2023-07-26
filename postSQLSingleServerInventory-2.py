import csv
import logging
import sys
import argparse
from typing import List, Tuple, Dict, Any
from azure.identity import DefaultAzureCredential
from azure.mgmt.resourcegraph import ResourceGraphClient
from azure.mgmt.subscription import SubscriptionClient
import pandas as pd


def get_subscription_id(sub_client, subscription_name: str) -> str:
    """
    Retrieves the subscription ID for a given subscription name.
    """
    try:
        subscription = list(
            sub_client.subscriptions.list(
                filter=f"displayName eq '{subscription_name}'"))
        return subscription[0].subscription_id if subscription else None
    except Exception as e:
        logging.error(f"Error getting subscription ID for {subscription_name}: {e}")
        return None


def is_valid_guid(subscription_id: str) -> bool:
    """
    Checks if a given subscription ID is a valid GUID (Globally Unique Identifier).
    """
    import re
    regex = re.compile(
        r'^[{\(]?[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[1-5][0-9a-fA-F]{3}'
        r'-?[89abAB][0-9a-fA-F]{3}-?[0-9a-fA-F]{12}[}\)]?$'
    )
    return bool(regex.match(subscription_id))


def save_subscriptions(filename: str, subscriptions: List[str]) -> None:
    """
    Saves a list of subscription names to a CSV file.
    """
    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(["SubscriptionName"])
        for sub in subscriptions:
            writer.writerow([sub])


def get_subscription_ids(batch: List[Dict[str, str]], sub_client) -> Tuple[
        List[Tuple[str, str]], List[str], List[str]]:
    """
    Retrieves subscription IDs for a batch of subscription names.
    """
    subscription_ids = []
    not_found_subs = []
    invalid_subs = []
    for row in batch:
        sub_id = get_subscription_id(sub_client, row['SubscriptionName'])
        if sub_id is not None:
            if is_valid_guid(sub_id):
                subscription_ids.append((sub_id, row['ResourceGroup']))
            else:
                invalid_subs.append(row['SubscriptionName'])
        else:
            not_found_subs.append(row['SubscriptionName'])

    logging.info(f"Subscription Ids: {subscription_ids}")
    return subscription_ids, not_found_subs, invalid_subs


def prepare_batches(lst: List[Any], n: int) -> List[List[Any]]:
    """
    Splits a list into batches of size `n`.
    """
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


def get_postgresql_servers(client, subscription_id: str,
                           resource_group: str = None) -> Any:
    """
    Retrieves PostgreSQL servers for a given subscription ID and optionally a resource group.
    """
    query = ("Resources | where type =~ 'Microsoft.DBforPostgreSQL/servers' |"
             " project subscriptionId, name, resourceGroup, location, sku")
    if resource_group:
        query += f"| where resourceGroup == '{resource_group}'"

    return client.resources(query, [subscription_id])


def main(input_file: str, batch_size: int, not_found_file: str, invalid_file: str):
    """
    Main function that orchestrates the entire process.
    """
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)

    try:
        df = pd.read_csv(input_file)
    except FileNotFoundError:
        logging.error(f"File {input_file} not found.")
        sys.exit(1)

    subscription_data = df[['SubscriptionName', 'ResourceGroup']].to_dict('records')

    try:
        credential = DefaultAzureCredential()
        resource_graph_client = ResourceGraphClient(credential)
        sub_client = SubscriptionClient(credential)
    except Exception as e:
        logging.error(f"Error initializing Azure clients: {e}")
        sys.exit(1)

    output = []
    for batch in prepare_batches(subscription_data, batch_size):
        subscription_ids, not_found_subs, invalid_subs = get_subscription_ids(
            batch, sub_client)
        save_subscriptions(not_found_file, not_found_subs)
        save_subscriptions(invalid_file, invalid_subs)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process Azure subscriptions.')
    parser.add_argument('--input', help='Input CSV file', default="subscriptions.csv")
    parser.add_argument('--batch_size', type=int, help='Batch size', default=500)
    parser.add_argument('--not_found_file', help='Output file for not found subscriptions', default='not_found_subscriptions.csv')
    parser.add_argument('--invalid_file', help='Output file for invalid subscriptions', default='invalid_subscriptions.csv')

    args = parser.parse_args()

    main(args.input, args.batch_size, args.not_found_file, args.invalid_file)
