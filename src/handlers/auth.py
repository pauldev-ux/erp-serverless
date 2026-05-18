import os
import boto3


_COGNITO_CLIENT = None


def _normalize_headers(headers):
    if not isinstance(headers, dict):
        return {}
    return {str(k).lower(): v for k, v in headers.items()}


def is_auth_enabled():
    return os.getenv('AUTH_ENABLED', 'false').strip().lower() in ('1', 'true', 'yes', 'on')


def _get_auth_provider():
    return os.getenv('AUTH_PROVIDER', 'header').strip().lower()


def _normalize_role(value):
    return str(value or '').strip().lower()


def _extract_bearer_token(headers):
    auth_value = str(headers.get('authorization', '')).strip()
    if not auth_value:
        return ''
    if auth_value.lower().startswith('bearer '):
        return auth_value[7:].strip()
    return auth_value


def _get_cognito_client():
    global _COGNITO_CLIENT
    if _COGNITO_CLIENT is None:
        region_name = os.getenv('AWS_REGION') or os.getenv('AWS_DEFAULT_REGION')
        _COGNITO_CLIENT = boto3.client('cognito-idp', region_name=region_name)
    return _COGNITO_CLIENT


def _extract_role_from_cognito_token(headers):
    token = _extract_bearer_token(headers)
    if not token:
        return '', 'No autorizado: falta token Bearer en Authorization'

    role_attr_name = os.getenv('COGNITO_ROLE_ATTRIBUTE', 'custom:role').strip()

    try:
        client = _get_cognito_client()
        user_data = client.get_user(AccessToken=token)
    except Exception:
        return '', 'No autorizado: token invalido o expirado'

    attrs = {attr.get('Name'): attr.get('Value') for attr in user_data.get('UserAttributes', [])}
    role_value = _normalize_role(attrs.get(role_attr_name, ''))
    if not role_value:
        return '', f'No autorizado: falta atributo de rol en Cognito ({role_attr_name})'

    return role_value, None


def check_role_access(event, allowed_roles):
    """
    Returns None when access is granted, otherwise returns an error message.
    Authorization is opt-in through AUTH_ENABLED env var.
    """
    if not is_auth_enabled():
        return None

    headers = _normalize_headers(event.get('headers') or {})
    provider = _get_auth_provider()

    role_value = ''
    role_error = None

    if provider in ('cognito', 'hybrid'):
        role_value, role_error = _extract_role_from_cognito_token(headers)

    if not role_value and provider in ('header', 'hybrid'):
        role_header = os.getenv('AUTH_HEADER', 'x-api-role').strip().lower()
        role_value = _normalize_role(headers.get(role_header, ''))
        if not role_value and provider == 'header':
            return 'No autorizado: falta encabezado de rol'

    if not role_value:
        return role_error or 'No autorizado: no se pudo resolver el rol del usuario'

    normalized_allowed = [_normalize_role(role) for role in allowed_roles]
    if role_value not in normalized_allowed:
        return f'Acceso denegado para rol: {role_value}'

    return None
