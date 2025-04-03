import hashlib
from typing import Any, Optional, ClassVar, Self, Mapping
from dataclasses import fields, Field, dataclass


@dataclass
class StructuredWildcard:
    _hash_store: ClassVar[Mapping[str, str]] = {}

    def _encode_field(self, field: Field) -> str:
        value = str(getattr(self, field.name))
        if "/" in value:
            m = hashlib.sha256()
            m.update(value.encode())
            hashed = m.hexdigest()
            self._hash_store[hashed] = value
            return f"{field.name}:hashed:{hashed}"
        return f"{field.name}:{value}"

    @classmethod
    def _decode_field(cls, field: Field, value: str) -> Any:
        if value.startswith(f"{field.name}:hashed:"):
            hashed = value[len(f"{field.name}:hashed:"):]
            decoded = cls._hash_store.get(hashed)
            if decoded is not None:
                return decoded
            raise ValueError(f"Hash '{hashed}' not found in hash store")
        elif value.startswith(f"{field.name}:"):
            return value[len(field.name) + 1:]
        else:
            raise ValueError(f"Invalid format (expected {field.name}:<value>): {value}")

    def into_wildcard_value(self) -> str:
        return "/".join(self._encode_field(field) for field in fields(self))

    @classmethod
    def from_wildcard_value(cls, wilcard_value: str, field: Optional[str] = None) -> Self:
        if wilcard_value is None:
            raise ValueError(f"Wildcard '{wildcard_name}' not found in wildcards")
        values = wilcard_value.split("/")
        cls_fields = fields(cls)
        if len(values) != len(cls_fields):
            raise ValueError(f"Invalid format: {wilcard_value}")
        obj = cls(**{field.name: cls._decode_field(field, value) for field, value in zip(cls_fields, values)})
        if field is not None:
            return getattr(obj, field)
        return obj

    def __str__(self):
        return self.into_wildcard_value()

    @classmethod
    def from_wildcard(cls, wildcard_name: str, field: Optional[str] = None):
        def inner(wildcards):
            encoded = wildcards.get(wildcard_name)
            return cls.from_wildcard_value(encoded, field=field)
        return inner


def task(name: str, item: Any):
    return touch(f"tasks/{name}/{item}.done")