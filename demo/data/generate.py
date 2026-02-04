#!/usr/bin/env python3
"""
Synthetic Data Generator for Apache NiFi Data Lakehouse Demo

Generates realistic e-commerce data with seasonal patterns and regional distributions.
Outputs: orders, customers, products in CSV/Parquet/JSON Lines formats.
"""

import argparse
import json
import random
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple

import pandas as pd
from faker import Faker


class DataGenerator:
    """Generate synthetic e-commerce data with realistic distributions."""

    REGIONS = ["North", "South", "East", "West"]
    REGION_WEIGHTS = [0.40, 0.25, 0.20, 0.15]  # North-heavy distribution

    STATUSES = ["completed", "pending", "cancelled", "refunded"]
    STATUS_WEIGHTS = [0.80, 0.10, 0.08, 0.02]

    PAYMENT_METHODS = ["credit_card", "debit_card", "paypal", "bank_transfer"]
    PAYMENT_WEIGHTS = [0.60, 0.25, 0.10, 0.05]

    CATEGORIES = {
        "Electronics": ["Laptop", "Smartphone", "Tablet", "Headphones", "Camera"],
        "Clothing": ["T-Shirt", "Jeans", "Jacket", "Dress", "Shoes"],
        "Home": ["Blender", "Vacuum", "Lamp", "Chair", "Desk"],
        "Books": ["Fiction", "Non-Fiction", "Technical", "Biography", "Cookbook"],
        "Sports": ["Running Shoes", "Yoga Mat", "Dumbbells", "Bicycle", "Tennis Racket"],
    }

    def __init__(self, seed: int = 42):
        """Initialize generator with reproducible seed."""
        self.fake = Faker()
        Faker.seed(seed)
        random.seed(seed)

    def generate_products(self, count: int = 50) -> pd.DataFrame:
        """Generate product catalog."""
        products = []
        product_id = 1

        for category, subcategories in self.CATEGORIES.items():
            for subcategory in subcategories:
                if product_id > count:
                    break

                # Price tiers: 60% low (<$100), 30% mid ($100-$500), 10% high (>$500)
                tier = random.choices(
                    ["low", "mid", "high"], weights=[0.60, 0.30, 0.10]
                )[0]

                if tier == "low":
                    base_price = round(random.uniform(10, 99), 2)
                elif tier == "mid":
                    base_price = round(random.uniform(100, 499), 2)
                else:
                    base_price = round(random.uniform(500, 2000), 2)

                cost = round(base_price * random.uniform(0.4, 0.7), 2)
                margin = round(((base_price - cost) / base_price) * 100, 2)

                products.append(
                    {
                        "product_id": product_id,
                        "product_name": f"{category} - {subcategory}",
                        "category": category,
                        "subcategory": subcategory,
                        "base_price": base_price,
                        "cost": cost,
                        "margin": margin,
                    }
                )
                product_id += 1

        return pd.DataFrame(products)

    def generate_customers(self, count: int = 10000) -> pd.DataFrame:
        """Generate customer master data."""
        customers = []

        for customer_id in range(1, count + 1):
            registration_date = self.fake.date_time_between(
                start_date="-5y", end_date="-1d"
            )
            region = random.choices(self.REGIONS, weights=self.REGION_WEIGHTS)[0]
            lifetime_value = round(random.uniform(50, 10000), 2)

            customers.append(
                {
                    "customer_id": customer_id,
                    "first_name": self.fake.first_name(),
                    "last_name": self.fake.last_name(),
                    "email": self.fake.email(),
                    "phone": self.fake.phone_number(),
                    "registration_date": registration_date,
                    "region": region,
                    "lifetime_value": lifetime_value,
                }
            )

        return pd.DataFrame(customers)

    def _get_seasonal_multiplier(self, date: datetime) -> float:
        """Return seasonal spike multiplier (Q4 spike for holidays)."""
        month = date.month
        if month in [11, 12]:  # Nov-Dec holiday season
            return 2.0
        elif month in [1, 7]:  # Jan (returns), Jul (summer)
            return 0.7
        else:
            return 1.0

    def generate_orders(
        self,
        count: int,
        customers_df: pd.DataFrame,
        products_df: pd.DataFrame,
        start_date: datetime = None,
        end_date: datetime = None,
    ) -> pd.DataFrame:
        """Generate order transactions with seasonal patterns."""
        if start_date is None:
            start_date = datetime.now() - timedelta(days=730)  # 2 years
        if end_date is None:
            end_date = datetime.now()

        orders = []
        customer_ids = customers_df["customer_id"].tolist()
        customer_regions = dict(
            zip(customers_df["customer_id"], customers_df["region"])
        )
        product_ids = products_df["product_id"].tolist()
        product_data = products_df.set_index("product_id").to_dict("index")

        # Track first purchase per customer
        customer_first_purchase = set()

        for order_id in range(1, count + 1):
            # Generate random date with seasonal distribution
            days_range = (end_date - start_date).days
            random_days = random.randint(0, days_range)
            order_date = start_date + timedelta(days=random_days)

            # Apply seasonal multiplier to status (more completions in high season)
            seasonal_mult = self._get_seasonal_multiplier(order_date)
            adjusted_weights = [w * seasonal_mult if i == 0 else w for i, w in enumerate(self.STATUS_WEIGHTS)]
            total = sum(adjusted_weights)
            adjusted_weights = [w / total for w in adjusted_weights]

            customer_id = random.choice(customer_ids)
            product_id = random.choice(product_ids)
            product = product_data[product_id]

            # Quantity: mostly 1-3, occasionally bulk
            quantity = random.choices([1, 2, 3, 4, 5, 10], weights=[0.5, 0.25, 0.15, 0.05, 0.03, 0.02])[0]

            # Price with random variance (-10% to +10%)
            unit_price = round(product["base_price"] * random.uniform(0.9, 1.1), 2)
            subtotal = round(unit_price * quantity, 2)

            # Discount: 70% none, 20% 10%, 10% 20%
            discount_pct = random.choices([0, 0.10, 0.20], weights=[0.70, 0.20, 0.10])[0]
            discount_amount = round(subtotal * discount_pct, 2)

            # Tax: 8%
            taxable = subtotal - discount_amount
            tax_amount = round(taxable * 0.08, 2)

            total_amount = round(taxable + tax_amount, 2)

            # Shipping: free over $100, else $9.99
            shipping_cost = 0.0 if total_amount > 100 else 9.99

            is_first_purchase = customer_id not in customer_first_purchase
            if is_first_purchase:
                customer_first_purchase.add(customer_id)

            order_timestamp = order_date.replace(
                hour=random.randint(0, 23),
                minute=random.randint(0, 59),
                second=random.randint(0, 59),
            )

            orders.append(
                {
                    "order_id": order_id,
                    "customer_id": customer_id,
                    "product_id": product_id,
                    "product_name": product["product_name"],
                    "quantity": quantity,
                    "unit_price": unit_price,
                    "total_amount": total_amount,
                    "discount_amount": discount_amount,
                    "tax_amount": tax_amount,
                    "order_date": order_date.date(),
                    "order_timestamp": order_timestamp,
                    "region": customer_regions[customer_id],
                    "status": random.choices(self.STATUSES, weights=adjusted_weights)[0],
                    "payment_method": random.choices(
                        self.PAYMENT_METHODS, weights=self.PAYMENT_WEIGHTS
                    )[0],
                    "shipping_cost": shipping_cost,
                    "is_first_purchase": is_first_purchase,
                }
            )

        return pd.DataFrame(orders)

    def validate_schema(self, df: pd.DataFrame, entity: str) -> bool:
        """Validate dataframe schema before writing."""
        schemas = {
            "products": [
                "product_id",
                "product_name",
                "category",
                "subcategory",
                "base_price",
                "cost",
                "margin",
            ],
            "customers": [
                "customer_id",
                "first_name",
                "last_name",
                "email",
                "phone",
                "registration_date",
                "region",
                "lifetime_value",
            ],
            "orders": [
                "order_id",
                "customer_id",
                "product_id",
                "product_name",
                "quantity",
                "unit_price",
                "total_amount",
                "discount_amount",
                "tax_amount",
                "order_date",
                "order_timestamp",
                "region",
                "status",
                "payment_method",
                "shipping_cost",
                "is_first_purchase",
            ],
        }

        expected = schemas.get(entity, [])
        actual = df.columns.tolist()

        if set(expected) != set(actual):
            print(f"❌ Schema validation failed for {entity}", file=sys.stderr)
            print(f"   Expected: {expected}", file=sys.stderr)
            print(f"   Actual: {actual}", file=sys.stderr)
            return False

        print(f"✓ Schema validated for {entity}")
        return True

    def save_data(
        self, df: pd.DataFrame, entity: str, output_dir: Path, format: str
    ) -> None:
        """Save dataframe to specified format."""
        output_dir.mkdir(parents=True, exist_ok=True)

        if format == "csv":
            output_file = output_dir / f"{entity}.csv"
            df.to_csv(output_file, index=False)
            print(f"✓ Saved {output_file} ({len(df)} rows)")

        elif format == "parquet":
            output_file = output_dir / f"{entity}.parquet"
            df.to_parquet(output_file, index=False, compression="zstd")
            print(f"✓ Saved {output_file} ({len(df)} rows)")

        elif format == "jsonl":
            output_file = output_dir / f"{entity}.jsonl"
            with open(output_file, "w") as f:
                for record in df.to_dict("records"):
                    # Convert datetime objects to ISO strings
                    for key, value in record.items():
                        if isinstance(value, (datetime, pd.Timestamp)):
                            record[key] = value.isoformat()
                        elif isinstance(value, pd.Timestamp):
                            record[key] = value.isoformat()
                    f.write(json.dumps(record) + "\n")
            print(f"✓ Saved {output_file} ({len(df)} rows)")

        else:
            raise ValueError(f"Unsupported format: {format}")


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Generate synthetic e-commerce data for Data Lakehouse demo"
    )
    parser.add_argument(
        "--volume",
        type=int,
        default=100000,
        help="Number of order records to generate (default: 100000)",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="demo/data/output",
        help="Output directory (default: demo/data/output)",
    )
    parser.add_argument(
        "--format",
        type=str,
        choices=["csv", "parquet", "jsonl"],
        default="csv",
        help="Output format (default: csv)",
    )
    parser.add_argument(
        "--seed", type=int, default=42, help="Random seed for reproducibility (default: 42)"
    )

    args = parser.parse_args()

    print(f"\n{'='*60}")
    print("Data Lakehouse - Synthetic Data Generator")
    print(f"{'='*60}\n")
    print(f"Configuration:")
    print(f"  Orders: {args.volume:,}")
    print(f"  Output: {args.output}")
    print(f"  Format: {args.format}")
    print(f"  Seed: {args.seed}\n")

    generator = DataGenerator(seed=args.seed)
    output_dir = Path(args.output)

    # Generate products
    print("Generating products...")
    products_df = generator.generate_products(count=50)
    if not generator.validate_schema(products_df, "products"):
        sys.exit(1)
    generator.save_data(products_df, "products", output_dir, args.format)

    # Generate customers
    print("\nGenerating customers...")
    customers_df = generator.generate_customers(count=10000)
    if not generator.validate_schema(customers_df, "customers"):
        sys.exit(1)
    generator.save_data(customers_df, "customers", output_dir, args.format)

    # Generate orders
    print(f"\nGenerating {args.volume:,} orders...")
    orders_df = generator.generate_orders(
        count=args.volume, customers_df=customers_df, products_df=products_df
    )
    if not generator.validate_schema(orders_df, "orders"):
        sys.exit(1)
    generator.save_data(orders_df, "orders", output_dir, args.format)

    # Summary statistics
    print(f"\n{'='*60}")
    print("Generation Summary")
    print(f"{'='*60}")
    print(f"\nProducts: {len(products_df):,} records")
    print(f"  Categories: {products_df['category'].nunique()}")
    print(f"  Price range: ${products_df['base_price'].min():.2f} - ${products_df['base_price'].max():.2f}")

    print(f"\nCustomers: {len(customers_df):,} records")
    print(f"  Regions: {', '.join(customers_df['region'].unique())}")
    print(f"  Region distribution:")
    for region, count in customers_df["region"].value_counts().items():
        print(f"    {region}: {count:,} ({count/len(customers_df)*100:.1f}%)")

    print(f"\nOrders: {len(orders_df):,} records")
    print(f"  Date range: {orders_df['order_date'].min()} to {orders_df['order_date'].max()}")
    print(f"  Total revenue: ${orders_df['total_amount'].sum():,.2f}")
    print(f"  Average order value: ${orders_df['total_amount'].mean():.2f}")
    print(f"  Status distribution:")
    for status, count in orders_df["status"].value_counts().items():
        print(f"    {status}: {count:,} ({count/len(orders_df)*100:.1f}%)")

    print(f"\n✓ Data generation complete!\n")


if __name__ == "__main__":
    main()
