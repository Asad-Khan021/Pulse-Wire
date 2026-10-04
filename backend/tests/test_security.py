import pytest
from datetime import timedelta
from app.core.security import extract_user_context
from app.core.exceptions import UnauthorizedException


def test_valid_jwt_extraction(create_test_jwt):
    """Verifies that a valid token correctly extracts UserContext."""
    token = create_test_jwt(user_id="user-42", email="ayesha@example.com")
    context = extract_user_context(token)

    assert context.user_id == "user-42"
    assert context.email == "ayesha@example.com"
    assert context.role == "authenticated"


def test_expired_jwt_rejection(create_test_jwt):
    """Verifies that an expired token raises UnauthorizedException."""
    token = create_test_jwt(expires_delta=timedelta(seconds=-10))
    with pytest.raises(UnauthorizedException) as exc_info:
        extract_user_context(token)

    assert exc_info.value.code == "UNAUTHORIZED"


def test_tampered_jwt_rejection(create_test_jwt):
    """Verifies that a token with modified payload/signature is rejected."""
    token = create_test_jwt()
    tampered_token = token[:-4] + "xyz1"
    with pytest.raises(UnauthorizedException) as exc_info:
        extract_user_context(tampered_token)

    assert exc_info.value.code == "UNAUTHORIZED"


def test_empty_or_whitespace_jwt():
    """Verifies that empty tokens raise UnauthorizedException."""
    with pytest.raises(UnauthorizedException):
        extract_user_context("")

    with pytest.raises(UnauthorizedException):
        extract_user_context("   ")
