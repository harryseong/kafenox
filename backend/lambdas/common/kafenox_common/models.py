import os

from pynamodb.attributes import (
    BooleanAttribute,
    ListAttribute,
    NumberAttribute,
    UnicodeAttribute,
)
from pynamodb.models import Model


class CoffeeModel(Model):
    class Meta:
        table_name = os.environ.get("COFFEE_TABLE_NAME", "kafenox-coffees-dev")
        region = os.environ.get("AWS_REGION", "ap-southeast-1")

    photoId = UnicodeAttribute(hash_key=True)
    status = UnicodeAttribute()
    errorMessage = UnicodeAttribute(null=True)
    createdAt = UnicodeAttribute(null=True)
    extractedAt = UnicodeAttribute(null=True)
    rawImageKey = UnicodeAttribute(null=True)
    processedImageKey = UnicodeAttribute(null=True)

    roaster = UnicodeAttribute(null=True)
    coffeeName = UnicodeAttribute(null=True)
    originCountry = UnicodeAttribute(null=True)
    originRegion = UnicodeAttribute(null=True)
    roastDate = UnicodeAttribute(null=True)
    roastLevel = UnicodeAttribute(null=True)
    roastType = UnicodeAttribute(null=True)
    process = UnicodeAttribute(null=True)
    variety = UnicodeAttribute(null=True)
    producer = UnicodeAttribute(null=True)
    flavorNotes = ListAttribute(of=UnicodeAttribute, default=list, null=True)
    altitude = UnicodeAttribute(null=True)

    lat = NumberAttribute(null=True)
    lng = NumberAttribute(null=True)

    rating = NumberAttribute(null=True)
    isVerified = BooleanAttribute(default=False)

    def to_dict(self) -> dict:
        return dict(self.attribute_values)
