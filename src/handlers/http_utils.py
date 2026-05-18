import json


def build_response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-api-role, x-tenant-id',
            'X-Content-Type-Options': 'nosniff'
        },
        'body': json.dumps(body)
    }


def error_response(status_code, message, details=None):
    error_payload = {
        'ok': False,
        'error': {
            'status': status_code,
            'message': message
        }
    }
    if details is not None:
        error_payload['error']['details'] = details
    return build_response(status_code, error_payload)


def parse_json_body(raw_body):
    if not raw_body:
        return {}
    try:
        return json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise ValueError('JSON invalido en el body') from exc


def resolve_table_name(raw_name, default_name):
    """
    In local SAM, env vars sourced from !Ref can arrive as logical IDs
    (e.g. ProductosTable) instead of explicit physical names.
    """
    if not raw_name:
        return default_name

    value = str(raw_name).strip()
    logical_like = value.endswith('Table') and value.lower() != default_name.lower()
    if logical_like:
        return default_name

    return value
