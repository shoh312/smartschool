def normalize_phone(phone: str) -> str:
    """Digits only, so "+992987644002", "992987644002" and "992 987 64 40 02"
    are all recognized as the same parent instead of creating duplicates.
    """
    return "".join(char for char in phone if char.isdigit())
