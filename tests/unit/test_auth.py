import os

from auth import check_role_access


def test_check_role_access_disabled_allows_anything(monkeypatch):
    monkeypatch.setenv('AUTH_ENABLED', 'false')
    event = {'headers': {}}

    assert check_role_access(event, ['admin']) is None


def test_check_role_access_missing_role_header_denied(monkeypatch):
    monkeypatch.setenv('AUTH_ENABLED', 'true')
    monkeypatch.setenv('AUTH_HEADER', 'x-api-role')
    event = {'headers': {}}

    assert check_role_access(event, ['admin']) == 'No autorizado: falta encabezado de rol'


def test_check_role_access_allowed_role(monkeypatch):
    monkeypatch.setenv('AUTH_ENABLED', 'true')
    monkeypatch.setenv('AUTH_HEADER', 'x-api-role')
    event = {'headers': {'x-api-role': 'admin'}}

    assert check_role_access(event, ['admin', 'vendedor']) is None


def test_check_role_access_cognito_allowed(monkeypatch):
    class FakeCognitoClient:
        def get_user(self, AccessToken):
            return {
                'UserAttributes': [
                    {'Name': 'custom:role', 'Value': 'admin'}
                ]
            }

    monkeypatch.setenv('AUTH_ENABLED', 'true')
    monkeypatch.setenv('AUTH_PROVIDER', 'cognito')
    monkeypatch.setenv('COGNITO_ROLE_ATTRIBUTE', 'custom:role')
    monkeypatch.setattr('auth._get_cognito_client', lambda: FakeCognitoClient())

    event = {'headers': {'Authorization': 'Bearer test-token'}}
    assert check_role_access(event, ['admin']) is None


def test_check_role_access_cognito_missing_token(monkeypatch):
    monkeypatch.setenv('AUTH_ENABLED', 'true')
    monkeypatch.setenv('AUTH_PROVIDER', 'cognito')

    event = {'headers': {}}
    assert check_role_access(event, ['admin']) == 'No autorizado: falta token Bearer en Authorization'
