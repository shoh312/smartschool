TAJIKISTAN_CODE = "992"
LOCAL_NUMBER_LENGTH = 9


def normalize_phone(phone: str) -> str:
    digits = "".join(char for char in phone if char.isdigit())
    if not digits:
        return digits

    if digits.startswith("00"):
        digits = digits[2:]

    if digits.startswith(TAJIKISTAN_CODE) and len(digits) == len(TAJIKISTAN_CODE) + LOCAL_NUMBER_LENGTH:
        return digits

    if digits.startswith("0") and len(digits) == LOCAL_NUMBER_LENGTH + 1:
        digits = digits[1:]

    if len(digits) == LOCAL_NUMBER_LENGTH:
        return TAJIKISTAN_CODE + digits

    return digits
