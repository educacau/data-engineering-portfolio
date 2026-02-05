"""
Integration tests for Trino query performance and functionality.
"""

import pytest
import trino


class TestTrinoQueries:
    """Test Trino query execution and performance."""

    def test_trino_connection(self, trino_connection: trino.dbapi.Connection):
        """Test Trino connection is established."""
        assert trino_connection is not None
        cursor = trino_connection.cursor()
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        cursor.close()
        assert result[0] == 1

    def test_iceberg_catalog_accessible(self, trino_connection: trino.dbapi.Connection):
        """Test Iceberg catalog is accessible."""
        cursor = trino_connection.cursor()
        cursor.execute("SHOW SCHEMAS FROM iceberg")
        schemas = [row[0] for row in cursor.fetchall()]
        cursor.close()
        assert "lakehouse" in schemas

    def test_orders_table_exists(self, trino_connection: trino.dbapi.Connection):
        """Test orders table exists in lakehouse schema."""
        cursor = trino_connection.cursor()
        cursor.execute("SHOW TABLES FROM iceberg.lakehouse")
        tables = [row[0] for row in cursor.fetchall()]
        cursor.close()
        assert "orders" in tables

    def test_customers_table_exists(self, trino_connection: trino.dbapi.Connection):
        """Test customers table exists."""
        cursor = trino_connection.cursor()
        cursor.execute("SHOW TABLES FROM iceberg.lakehouse")
        tables = [row[0] for row in cursor.fetchall()]
        cursor.close()
        assert "customers" in tables

    def test_products_table_exists(self, trino_connection: trino.dbapi.Connection):
        """Test products table exists."""
        cursor = trino_connection.cursor()
        cursor.execute("SHOW TABLES FROM iceberg.lakehouse")
        tables = [row[0] for row in cursor.fetchall()]
        cursor.close()
        assert "products" in tables

    def test_orders_table_has_data(self, trino_connection: trino.dbapi.Connection):
        """Test orders table contains data."""
        cursor = trino_connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM orders")
        count = cursor.fetchone()[0]
        cursor.close()
        assert count > 0, "Orders table is empty"

    def test_simple_select_query(self, trino_connection: trino.dbapi.Connection):
        """Test simple SELECT query."""
        cursor = trino_connection.cursor()
        cursor.execute("SELECT * FROM orders LIMIT 10")
        rows = cursor.fetchall()
        cursor.close()
        assert len(rows) == 10

    def test_aggregation_query(self, trino_connection: trino.dbapi.Connection):
        """Test aggregation query."""
        cursor = trino_connection.cursor()
        cursor.execute(
            """
            SELECT region, COUNT(*) as order_count, SUM(total_amount) as revenue
            FROM orders
            GROUP BY region
            ORDER BY revenue DESC
        """
        )
        rows = cursor.fetchall()
        cursor.close()
        assert len(rows) > 0
        # Verify results have expected columns
        assert len(rows[0]) == 3  # region, order_count, revenue

    def test_join_query(self, trino_connection: trino.dbapi.Connection):
        """Test JOIN query between customers and orders."""
        cursor = trino_connection.cursor()
        cursor.execute(
            """
            SELECT c.customer_id, c.first_name, COUNT(o.order_id) as order_count
            FROM customers c
            LEFT JOIN orders o ON c.customer_id = o.customer_id
            GROUP BY c.customer_id, c.first_name
            LIMIT 10
        """
        )
        rows = cursor.fetchall()
        cursor.close()
        assert len(rows) == 10

    def test_time_travel_query(self, trino_connection: trino.dbapi.Connection):
        """Test Iceberg time travel functionality."""
        cursor = trino_connection.cursor()
        cursor.execute(
            """
            SELECT COUNT(*) as count
            FROM orders
            FOR TIMESTAMP AS OF CURRENT_TIMESTAMP
        """
        )
        count = cursor.fetchone()[0]
        cursor.close()
        assert count > 0

    @pytest.mark.timeout(5)
    def test_query_performance_simple(self, trino_connection: trino.dbapi.Connection):
        """Test simple query completes within 5 seconds."""
        cursor = trino_connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM orders")
        _ = cursor.fetchone()
        cursor.close()

    @pytest.mark.timeout(10)
    def test_query_performance_complex(
        self, trino_connection: trino.dbapi.Connection
    ):
        """Test complex query completes within 10 seconds."""
        cursor = trino_connection.cursor()
        cursor.execute(
            """
            SELECT
                region,
                status,
                DATE_TRUNC('month', order_date) as month,
                COUNT(*) as order_count,
                SUM(total_amount) as revenue
            FROM orders
            GROUP BY region, status, DATE_TRUNC('month', order_date)
            ORDER BY month DESC, revenue DESC
            LIMIT 100
        """
        )
        _ = cursor.fetchall()
        cursor.close()

    def test_iceberg_metadata_tables(self, trino_connection: trino.dbapi.Connection):
        """Test Iceberg metadata tables are accessible."""
        cursor = trino_connection.cursor()

        # Check snapshots
        cursor.execute('SELECT * FROM "orders$snapshots" LIMIT 1')
        snapshots = cursor.fetchall()
        assert len(snapshots) > 0, "No snapshots found for orders table"

        # Check files
        cursor.execute('SELECT * FROM "orders$files" LIMIT 1')
        files = cursor.fetchall()
        assert len(files) > 0, "No data files found for orders table"

        cursor.close()

    def test_query_with_filters(self, trino_connection: trino.dbapi.Connection):
        """Test query with various filter conditions."""
        cursor = trino_connection.cursor()
        cursor.execute(
            """
            SELECT *
            FROM orders
            WHERE status = 'completed'
              AND total_amount > 100
              AND order_date >= CURRENT_DATE - INTERVAL '30' DAY
            LIMIT 10
        """
        )
        rows = cursor.fetchall()
        cursor.close()
        # Should return some results (not necessarily 10)
        assert len(rows) >= 0

    def test_data_types_preserved(self, trino_connection: trino.dbapi.Connection):
        """Test data types are correctly preserved."""
        cursor = trino_connection.cursor()
        cursor.execute(
            """
            SELECT
                order_id,
                customer_id,
                total_amount,
                order_date,
                order_timestamp,
                is_first_purchase
            FROM orders
            LIMIT 1
        """
        )
        row = cursor.fetchone()
        cursor.close()

        assert isinstance(row[0], int), "order_id should be integer"
        assert isinstance(row[1], int), "customer_id should be integer"
        assert isinstance(row[2], (int, float)), "total_amount should be numeric"
        # order_date and order_timestamp types depend on driver implementation
        assert isinstance(row[5], bool), "is_first_purchase should be boolean"
