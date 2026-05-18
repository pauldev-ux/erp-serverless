import json

import pytest

from http_utils import build_response, parse_json_body, resolve_table_name


def test_build_response_has_expected_structure():
    resp = build_response(200, {'ok': True})

    assert resp['statusCode'] == 200
    assert resp['headers']['Content-Type'] == 'application/json'
    assert json.loads(resp['body']) == {'ok': True}


def test_parse_json_body_invalid_raises_value_error():
    with pytest.raises(ValueError):
        parse_json_body('{"foo":')


def test_resolve_table_name_maps_logical_id_to_default():
    assert resolve_table_name('ProductosTable', 'productos') == 'productos'
    assert resolve_table_name('productos', 'productos') == 'productos'
