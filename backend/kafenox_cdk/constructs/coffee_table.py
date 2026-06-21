from aws_cdk import RemovalPolicy
from aws_cdk import aws_dynamodb as dynamodb
from constructs import Construct


class CoffeeTable(Construct):
    """DynamoDB table holding one item per coffee bag, keyed by photoId.

    No GSIs: at the scale of "a few hundred bags ever", list_coffees does a
    table Scan + in-Lambda filtering, which is simpler than maintaining GSIs
    and lowercase-helper attributes. Revisit only if item count grows past
    ~5-10k.
    """

    def __init__(self, scope: Construct, construct_id: str, *, env_name: str) -> None:
        super().__init__(scope, construct_id)

        self.table = dynamodb.Table(
            self,
            "Table",
            table_name=f"kafenox-coffees-{env_name}",
            partition_key=dynamodb.Attribute(
                name="photoId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            removal_policy=RemovalPolicy.RETAIN,
            point_in_time_recovery=True,
        )
