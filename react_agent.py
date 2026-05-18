#!/usr/bin/env python3
"""
Agente ReAct Simple para ERP Serverless
Implementa el patrón Thought → Action → Observation → Final Answer
sin usar IA externa, solo parsing de lenguaje natural y regex.
"""

import re
import sys
import requests
from typing import Dict, Any, Optional, Tuple

# Configuración
BASE_URL = "http://127.0.0.1:3000"
HEADERS_BASE = {
    "x-api-role": "admin"
}
HEADERS_JSON = {
    **HEADERS_BASE,
    "Content-Type": "application/json"
}

# Colores para output (opcional)
class Colors:
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    END = '\033[0m'


def print_section(title: str, color: str = Colors.CYAN):
    """Imprime un título de sección formateado."""
    print(f"\n{color}{Colors.BOLD}{title}{Colors.END}")
    print("-" * 60)


def parse_comando(comando: str) -> Tuple[str, Dict[str, Any]]:
    """
    Parsea el comando en lenguaje natural y extrae la intención y parámetros.
    
    Returns:
        Tuple de (tipo_comando, parámetros)
    """
    comando = comando.strip().lower()
    
    # Comando: crear producto
    match = re.match(
        r'crear\s+producto\s+(\w+(?:\s+\w+)*?)\s+precio\s+([\d.]+)\s+stock\s+(\d+)\s+categoria\s+(.+)',
        comando
    )
    if match:
        nombre, precio, stock, categoria = match.groups()
        return "crear_producto", {
            "nombre": nombre.strip(),
            "precio": float(precio),
            "stock": int(stock),
            "categoria": categoria.strip()
        }
    
    # Comando: crear cliente
    match = re.match(
        r'crear\s+cliente\s+(\w+(?:\s+\w+)*?)\s+email\s+(\S+)\s+telefono\s+(\S+)',
        comando
    )
    if match:
        nombre, email, telefono = match.groups()
        return "crear_cliente", {
            "nombre": nombre.strip(),
            "email": email.strip(),
            "telefono": telefono.strip()
        }
    
    # Comando: listar productos
    if re.match(r'listar\s+productos?$', comando):
        return "listar_productos", {}
    
    # Comando: listar clientes
    if re.match(r'listar\s+clientes?$', comando):
        return "listar_clientes", {}
    
    # Si no coincide nada
    return "desconocido", {}


def detectar_intencion(tipo_comando: str) -> str:
    """Retorna una descripción de la intención detectada."""
    intenciones = {
        "crear_producto": "El usuario quiere registrar un nuevo producto en el ERP con nombre, precio, stock y categoría.",
        "crear_cliente": "El usuario quiere registrar un nuevo cliente en el ERP con nombre, email y teléfono.",
        "listar_productos": "El usuario quiere ver todos los productos registrados en el ERP.",
        "listar_clientes": "El usuario quiere ver todos los clientes registrados en el ERP.",
        "desconocido": "No se reconoció el comando. Por favor, intente con una de las opciones disponibles."
    }
    return intenciones.get(tipo_comando, "Comando desconocido")


def crear_producto(params: Dict[str, Any]) -> Dict[str, Any]:
    """Crea un producto en el ERP."""
    try:
        payload = {
            "nombre": params["nombre"],
            "precio": params["precio"],
            "stock": params["stock"],
            "categoria": params["categoria"]
        }
        
        print(f"\n{Colors.YELLOW}Action: POST {BASE_URL}/productos{Colors.END}")
        print(f"Payload: {payload}")
        
        response = requests.post(
            f"{BASE_URL}/productos",
            json=payload,
            headers=HEADERS_JSON,
            timeout=5
        )
        
        response.raise_for_status()
        resultado = response.json()
        
        return {
            "exitoso": True,
            "datos": resultado,
            "mensaje": f"Producto '{params['nombre']}' creado exitosamente."
        }
    
    except requests.exceptions.ConnectionError:
        return {
            "exitoso": False,
            "error": "No se puede conectar al servidor ERP en http://127.0.0.1:3000. ¿Está corriendo 'sam local start'?"
        }
    except requests.exceptions.RequestException as e:
        return {
            "exitoso": False,
            "error": f"Error en la solicitud: {str(e)}"
        }
    except Exception as e:
        return {
            "exitoso": False,
            "error": f"Error inesperado: {str(e)}"
        }


def crear_cliente(params: Dict[str, Any]) -> Dict[str, Any]:
    """Crea un cliente en el ERP."""
    try:
        payload = {
            "nombre": params["nombre"],
            "email": params["email"],
            "telefono": params["telefono"]
        }
        
        print(f"\n{Colors.YELLOW}Action: POST {BASE_URL}/clientes{Colors.END}")
        print(f"Payload: {payload}")
        
        response = requests.post(
            f"{BASE_URL}/clientes",
            json=payload,
            headers=HEADERS_JSON,
            timeout=5
        )
        
        response.raise_for_status()
        resultado = response.json()
        
        return {
            "exitoso": True,
            "datos": resultado,
            "mensaje": f"Cliente '{params['nombre']}' creado exitosamente."
        }
    
    except requests.exceptions.ConnectionError:
        return {
            "exitoso": False,
            "error": "No se puede conectar al servidor ERP en http://127.0.0.1:3000. ¿Está corriendo 'sam local start'?"
        }
    except requests.exceptions.RequestException as e:
        return {
            "exitoso": False,
            "error": f"Error en la solicitud: {str(e)}"
        }
    except Exception as e:
        return {
            "exitoso": False,
            "error": f"Error inesperado: {str(e)}"
        }


def listar_productos() -> Dict[str, Any]:
    """Lista todos los productos del ERP."""
    try:
        print(f"\n{Colors.YELLOW}Action: GET {BASE_URL}/productos{Colors.END}")
        
        response = requests.get(
            f"{BASE_URL}/productos",
            headers=HEADERS_BASE,
            timeout=5
        )
        
        response.raise_for_status()
        resultado = response.json()
        
        # Formatear el resultado
        if isinstance(resultado, list):
            cantidad = len(resultado)
            mensaje = f"Se encontraron {cantidad} producto(s)."
        elif isinstance(resultado, dict) and "items" in resultado:
            cantidad = len(resultado["items"])
            mensaje = f"Se encontraron {cantidad} producto(s)."
            resultado = resultado["items"]
        else:
            mensaje = "Listado de productos obtenido."
        
        return {
            "exitoso": True,
            "datos": resultado,
            "mensaje": mensaje
        }
    
    except requests.exceptions.ConnectionError:
        return {
            "exitoso": False,
            "error": "No se puede conectar al servidor ERP en http://127.0.0.1:3000. ¿Está corriendo 'sam local start'?"
        }
    except requests.exceptions.RequestException as e:
        return {
            "exitoso": False,
            "error": f"Error en la solicitud: {str(e)}"
        }
    except Exception as e:
        return {
            "exitoso": False,
            "error": f"Error inesperado: {str(e)}"
        }


def listar_clientes() -> Dict[str, Any]:
    """Lista todos los clientes del ERP."""
    try:
        print(f"\n{Colors.YELLOW}Action: GET {BASE_URL}/clientes{Colors.END}")
        
        response = requests.get(
            f"{BASE_URL}/clientes",
            headers=HEADERS_BASE,
            timeout=5
        )
        
        response.raise_for_status()
        resultado = response.json()
        
        # Formatear el resultado
        if isinstance(resultado, list):
            cantidad = len(resultado)
            mensaje = f"Se encontraron {cantidad} cliente(s)."
        elif isinstance(resultado, dict) and "items" in resultado:
            cantidad = len(resultado["items"])
            mensaje = f"Se encontraron {cantidad} cliente(s)."
            resultado = resultado["items"]
        else:
            mensaje = "Listado de clientes obtenido."
        
        return {
            "exitoso": True,
            "datos": resultado,
            "mensaje": mensaje
        }
    
    except requests.exceptions.ConnectionError:
        return {
            "exitoso": False,
            "error": "No se puede conectar al servidor ERP en http://127.0.0.1:3000. ¿Está corriendo 'sam local start'?"
        }
    except requests.exceptions.RequestException as e:
        return {
            "exitoso": False,
            "error": f"Error en la solicitud: {str(e)}"
        }
    except Exception as e:
        return {
            "exitoso": False,
            "error": f"Error inesperado: {str(e)}"
        }


def ejecutar_accion(tipo_comando: str, params: Dict[str, Any]) -> Dict[str, Any]:
    """Ejecuta la acción correspondiente según el tipo de comando."""
    acciones = {
        "crear_producto": lambda: crear_producto(params),
        "crear_cliente": lambda: crear_cliente(params),
        "listar_productos": listar_productos,
        "listar_clientes": listar_clientes,
    }
    
    accion = acciones.get(tipo_comando)
    if accion:
        return accion()
    else:
        return {
            "exitoso": False,
            "error": "No se implementó la acción para este comando."
        }


def mostrar_ayuda():
    """Muestra los comandos disponibles."""
    print_section("Comandos disponibles", Colors.CYAN)
    print("""
1. Crear producto:
   crear producto <nombre> precio <precio> stock <stock> categoria <categoria>
   Ejemplo: crear producto "Laptop HP" precio 1200.50 stock 10 categoria Electrónica

2. Crear cliente:
   crear cliente <nombre> email <email> telefono <telefono>
   Ejemplo: crear cliente "Juan Pérez" email juan@example.com telefono 79123456

3. Listar productos:
   listar productos

4. Listar clientes:
   listar clientes

5. Salir:
   salir

Escriba 'ayuda' para ver esta información nuevamente.
    """)


def main():
    """Función principal con el loop interactivo."""
    print_section("Agente ReAct para ERP Serverless", Colors.GREEN)
    print(f"Conectando a: {BASE_URL}")
    print("Escriba 'ayuda' para ver los comandos disponibles.")
    print("Escriba 'salir' para terminar.\n")
    
    while True:
        try:
            # Solicitar comando
            comando = input(f"{Colors.BOLD}Comando > {Colors.END}").strip()
            
            if not comando:
                continue
            
            # Verificar si el usuario quiere salir
            if comando.lower() == "salir":
                print(f"\n{Colors.GREEN}¡Hasta luego!{Colors.END}")
                sys.exit(0)
            
            # Mostrar ayuda
            if comando.lower() == "ayuda":
                mostrar_ayuda()
                continue
            
            # Parsear comando
            tipo_comando, params = parse_comando(comando)
            
            # Paso 1: Thought
            print_section("Thought", Colors.CYAN)
            intencion = detectar_intencion(tipo_comando)
            print(intencion)
            
            if tipo_comando == "desconocido":
                print(f"\n{Colors.RED}Comando no reconocido. Escriba 'ayuda' para ver las opciones.{Colors.END}")
                continue
            
            # Paso 2 y 3: Action (mostrado dentro de ejecutar_accion)
            resultado = ejecutar_accion(tipo_comando, params)
            
            # Paso 4: Observation
            print_section("Observation", Colors.YELLOW)
            if resultado["exitoso"]:
                print(f"✓ Respuesta del servidor: {resultado['datos']}")
            else:
                print(f"✗ Error: {resultado['error']}")
            
            # Paso 5: Final Answer
            print_section("Final Answer", Colors.GREEN)
            if resultado["exitoso"]:
                print(f"✓ {resultado['mensaje']}")
            else:
                print(f"✗ {resultado['error']}")
        
        except KeyboardInterrupt:
            print(f"\n\n{Colors.GREEN}¡Hasta luego!{Colors.END}")
            sys.exit(0)
        except Exception as e:
            print(f"\n{Colors.RED}Error inesperado: {str(e)}{Colors.END}")
            continue


if __name__ == "__main__":
    main()
