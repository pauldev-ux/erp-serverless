import os


def _normalize_headers(headers):
    if not isinstance(headers, dict):
        return {}
    return {str(k).lower(): v for k, v in headers.items()}


def get_tenancy_mode():
    mode = os.getenv('TENANCY_MODE', 'single').strip().lower()
    return mode if mode in ('single', 'multi') else 'single'


def get_default_tenant_id():
    return os.getenv('DEFAULT_TENANT_ID', 'default').strip() or 'default'


def resolve_tenant_id(event):
    """
    Resolve tenant id from event and environment.

    single mode: always returns DEFAULT_TENANT_ID
    multi mode: expects tenant id in request header (x-tenant-id by default)
    """
    mode = get_tenancy_mode()
    if mode == 'single':
        return get_default_tenant_id(), None

    headers = _normalize_headers((event or {}).get('headers') or {})
    tenant_header = os.getenv('TENANT_HEADER', 'x-tenant-id').strip().lower()
    tenant_id = str(headers.get(tenant_header, '')).strip()

    if not tenant_id:
        return '', f'Falta tenant id en encabezado: {tenant_header}'

    return tenant_id, None


def item_belongs_to_tenant(item, tenant_id):
    """
    Backward compatible ownership check:
    - if item has tenantId, it must match tenant_id
    - if item has no tenantId, it is treated as default tenant data
    """
    if not isinstance(item, dict):
        return False

    item_tenant = item.get('tenantId')
    if item_tenant is None:
        return tenant_id == get_default_tenant_id()

    return str(item_tenant) == str(tenant_id)
