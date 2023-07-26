import csv
from typing import List, Tuple, Dict, Any
from azure.identity import DefaultAzureCredential
from azure.mgmt.resourcegraph import ResourceGraphClient
from azure.mgmt.subscription import SubscriptionClient
import pandas as pd
import logging


def get_subscription_id(sub_client, subscription_name: str) -> str:
    subscription = list(
        sub_client.subscriptions.list(
            filter=f"displayName eq '{subscription_name}'"))
    return subscription[0].subscription_id if subscription else None


def is_valid_guid(subscription_id: str) -> bool:
    import re
    regex = re.compile(
        r'^[{\(]?[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[1-5][0-9a-fA-F]{3}'
        r'-?[89abAB][0-9a-fA-F]{3}-?[0-9a-fA-F]{12}[}\)]?$'
    )
    return bool(regex.match(subscription_id))


def save_not_found_subscriptions(subscriptions: List[str]) -> None:
    with open('not_found_subscriptions.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(["SubscriptionName"])
        for sub in subscriptions:
            writer.writerow([sub])


def save_invalid_subscriptions(subscriptions: List[str]) -> None:
    with open('invalid_subscriptions.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(["SubscriptionName"])
        for sub in subscriptions:
            writer.writerow([sub])


def get_subscription_ids(batch: List[Dict[str, str]], sub_client) -> Tuple[
        List[Tuple[str, str]], List[str], List[str]]:
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
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


def get_postgresql_servers(client, subscription_id: str,
                           resource_group: str = None) -> Any:
    query = ("Resources | where type =~ 'Microsoft.DBforPostgreSQL/servers' |"
             " project subscriptionId, name, resourceGroup, location, sku")
    if resource_group:
        query += f"| where resourceGroup == '{resource_group}'"

    return client.resources(query, [subscription_id])


def main():
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)

    df = pd.read_csv("subscriptions.csv")
    subscription_data = df[['SubscriptionName', 'ResourceGroup']].to_dict(
        'records')

    credential = DefaultAzureCredential()
    resource_graph_client = ResourceGraphClient(credential)
    sub_client = SubscriptionClient(credential)

    batch_size = 500
    output = []
    for batch in prepare_batches(subscription_data, batch_size):
        subscription_ids, not_found_subs, invalid_subs = get_subscription_ids(
            batch, sub_
