"""
BaseModel class for database interaction.
This class provides methods for basic CRUD operations and is intended to be inherited by other models.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

class BaseModel:
    """
    Base model class for database interaction.
    """
    table_name = None  # The name of the table in the database, to be set or derived from the class name

    def __init__(self, **kwargs):
        """
        Class constructor that initializes the model with given keyword arguments.
        :param kwargs: Keyword arguments representing the attributes of the model.
        :return: None
        """
        # Initialize the model with keyword arguments
        for key, value in kwargs.items():
            setattr(self, key, value)

    def __getitem__(self, key):
        """
        Instance method to get an attribute by key.
        :param key: The key of the attribute to get.
        :return: The value of the attribute.
        """
        return getattr(self, key)

    @classmethod
    def get_table_name(cls):
        """
        Class method to get the table name for the model.
        If the table name is not set, it derives the name from the class name.
        :return: The name of the table in the database.
        """
        if not cls.table_name:
            cls.table_name = cls.__name__.lower() + "s"
        return cls.table_name

    @classmethod
    def from_row(cls, row):
        """
        Class method to create an instance of the model from a database row.
        :param row: The database row to create the instance from.
        :return: An instance of the model.
        """
        return cls(**dict(row))

    def as_dict(self):
        """
        Instance method to convert the model instance to a dictionary.
        :return: A dictionary representation of the model instance.
        """
        return self.__dict__

    @classmethod
    def find_one(cls, conn, **where):
        """
        Class method to find a single record in the database based on the provided criteria.
        :param conn: The database connection.
        :param where: The criteria to filter the records.
        :return: An instance of the model if found, otherwise None.
        """
        query = f"SELECT * FROM {cls.get_table_name()} WHERE "
        query += " AND ".join([f"{k}=%s" for k in where])
        values = tuple(where.values())
        with conn.cursor() as cur:
            cur.execute(query, values)
            row = cur.fetchone()
            return cls.from_row(row) if row else None

    @classmethod
    def find_all(cls, conn, **where):
        """
        Class method to find all records in the database based on the provided criteria.
        :param conn: The database connection.
        :param where: The criteria to filter the records.
        :return: A list of instances of the model.
        """
        query = f"SELECT * FROM {cls.get_table_name()}"
        values = []
        conditions = []

        for key, value in where.items():
            if isinstance(value, (list, tuple)):
                if len(value) == 0:
                    # Skip empty lists to avoid IN () syntax error
                    continue
                placeholders = ", ".join(["%s"] * len(value))
                conditions.append(f"{key} IN ({placeholders})")
                values.extend(value)
            else:
                conditions.append(f"{key} = %s")
                values.append(value)

        if conditions:
            query += " WHERE " + " AND ".join(conditions)
        with conn.cursor() as cur:
            cur.execute(query, tuple(values))
            return [cls.from_row(r) for r in cur.fetchall()]


    def insert(self, conn):
        """
        Method to insert a new record into the database.
        :param conn: The database connection.
        :return: The ID of the newly inserted record.
        """
        fields = {k: v for k, v in self.as_dict().items() if v is not None}
        keys = ", ".join(fields.keys())
        placeholders = ", ".join("%s" for _ in fields)
        values = tuple(fields.values())
        query = f"INSERT INTO {self.get_table_name()} ({keys}) VALUES ({placeholders}) RETURNING id"
        with conn.cursor() as cur:
            cur.execute(query, values)
            result = cur.fetchone()
            self.id = result['id'] if result else None
            return self.id

    @classmethod
    def update(cls, conn, pk_field, pk_value, **updates):
        """
        Class method to update an existing record in the database.
        :param conn: The database connection.
        :param pk_field: The primary key field name.
        :param pk_value: The primary key value of the record to update.
        :param updates: The fields to update and their new values.
        :return: None
        """
        keys = ", ".join([f"{k}=%s" for k in updates])
        values = tuple(updates.values()) + (pk_value,)
        query = f"UPDATE {cls.get_table_name()} SET {keys} WHERE {pk_field} = %s"
        with conn.cursor() as cur:
            cur.execute(query, values)

    @classmethod
    def delete(cls, conn, **where):
        """
        Class method to delete a record from the database based on the provided criteria.
        :param conn: The database connection.
        :param where: The criteria to filter the records to delete.
        :return: None
        """
        query = f"DELETE FROM {cls.get_table_name()} WHERE "
        query += " AND ".join([f"{k}=%s" for k in where])
        values = tuple(where.values())
        with conn.cursor() as cur:
            cur.execute(query, values)
