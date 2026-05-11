from flask import Flask, request, jsonify, render_template, send_from_directory
from flask_cors import CORS
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
import traceback 

from dotenv import load_dotenv
load_dotenv()

app = Flask(__name__)
CORS(app)

# --- CONFIGURACIÓN DE BASE DE DATOS (NEON) ---
DB_URL = os.environ.get('DATABASE_URL', '')

def get_db_connection():
    return psycopg2.connect(
        DB_URL,
        keepalives=1,
        keepalives_idle=30,
        keepalives_interval=10,
        keepalives_count=5
    )

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads', 'documentos')

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# --- SERVIR ARCHIVOS AL PANEL ADMIN ---
@app.route('/uploads/documentos/user_<int:user_id>/<filename>')
def ver_archivo(user_id, filename):
    directorio_usuario = os.path.join(UPLOAD_FOLDER, f"user_{user_id}")
    return send_from_directory(directorio_usuario, filename)

@app.route('/')
def index():
    return jsonify({
        "status": "online",
        "message": "Servidor de Jaydi Express funcionando 🚀"
    })

# --- PANEL ADMINISTRATIVO ---
@app.route('/admin')
def admin_panel():
    return render_template('admin.html')

@app.route('/admin/api/repartidores', methods=['GET'])
def listar_repartidores():
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        # ACÁ AHORA BUSCAMOS 'email'
        cur.execute("""
            SELECT id, nombre, email, es_verificado, 
                   COALESCE(saldo_acumulado, 0) as saldo, 
                   ultima_conexion 
            FROM usuarios 
            WHERE rol = 'repartidor'
            ORDER BY es_verificado ASC, ultima_conexion DESC NULLS LAST
        """)
        repartidores = cur.fetchall()
        cur.close()
        return jsonify(repartidores), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/admin/aprobar/<int:user_id>', methods=['POST', 'GET'])
def aprobar_repartidor(user_id):
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("UPDATE usuarios SET es_verificado = TRUE WHERE id = %s", (user_id,))
        conn.commit()
        cur.close()
        return jsonify({"status": "success", "message": "Repartidor aprobado"}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

# --- ENDPOINTS PARA LA APP (FLUTTER) ---

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        ahora = datetime.now()
        # ACÁ AHORA ES ESTRICTO CON EMAIL Y PASSWORD
        cur.execute("""
            UPDATE usuarios 
            SET ultima_conexion = %s 
            WHERE email = %s AND password = %s 
            RETURNING id, nombre, email, es_verificado, rol
        """, (ahora, email, password))
        
        user = cur.fetchone()
        conn.commit()
        cur.close()
        
        if user:
            return jsonify({
                "status": "success",
                "userData": {
                    "id": str(user['id']),
                    "nombre": user['nombre'],
                    "email": user['email'], # <- Manda el email de vuelta
                    "verificado": user['es_verificado']
                }
            }), 200
        return jsonify({"error": "Credenciales inválidas"}), 401
    except Exception as e:
        traceback.print_exc()
        if conn: conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/registro', methods=['POST'])
@app.route('/registrar', methods=['POST'])
def registro():
    data = request.json
    nombre = data.get('nombre')
    email = data.get('email')
    password = data.get('password') 
    rol = data.get('rol', 'repartidor')
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT id FROM usuarios WHERE email = %s", (email,))
        if cur.fetchone():
            cur.close()
            return jsonify({"error": "El email ya existe"}), 400
        
        cur.execute("""
            INSERT INTO usuarios (nombre, email, password, rol, es_verificado, saldo_acumulado, ultima_conexion)
            VALUES (%s, %s, %s, %s, FALSE, 0.0, CURRENT_TIMESTAMP) 
            RETURNING id, nombre, email
        """, (nombre, email, password, rol))
        nuevo = cur.fetchone()
        conn.commit()
        cur.close()
        return jsonify({
            "status": "success",
            "userData": {"id": str(nuevo['id']), "nombre": nuevo['nombre'], "email": nuevo['email']}
        }), 201
    except Exception as e:
        traceback.print_exc()
        if conn: conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

# 🔥 EL ENDPOINT QUE FALTABA PARA QUE PERFIL_SCREEN FUNCIONE 🔥
@app.route('/perfil/<int:user_id>', methods=['GET', 'PUT'])
def gestionar_perfil(user_id):
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        if request.method == 'GET':
            cur.execute("""
                SELECT telefono, vehiculo, placa, viajes_completados, 
                       COALESCE(saldo_acumulado, 0) as saldo, foto_perfil 
                FROM usuarios WHERE id = %s
            """, (user_id,))
            user = cur.fetchone()
            cur.close()
            if not user:
                return jsonify({"error": "Usuario no encontrado"}), 404
            return jsonify(user), 200

        if request.method == 'PUT':
            data = request.json
            if 'foto_perfil' in data:
                cur.execute("UPDATE usuarios SET foto_perfil = %s WHERE id = %s", (data['foto_perfil'], user_id))
                conn.commit()
            cur.close()
            return jsonify({"status": "success", "message": "Perfil actualizado"}), 200

    except Exception as e:
        traceback.print_exc()
        if conn: conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/subir_documento', methods=['POST'])
def subir_documento():
    if 'file' not in request.files:
        return jsonify({"error": "No hay archivo"}), 400
    
    file = request.files['file']
    user_id = request.form.get('user_id')
    tipo = request.form.get('tipo', 'documento')
    conn = None

    try:
        user_folder = os.path.join(UPLOAD_FOLDER, f"user_{user_id}")
        if not os.path.exists(user_folder):
            os.makedirs(user_folder)

        filename = f"{tipo}.jpg"
        path = os.path.join(user_folder, filename)
        file.save(path)

        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute("""
                INSERT INTO documentos_repartidor (user_id, tipo_documento, ruta_archivo_servidor)
                VALUES (%s, %s, %s)
                ON CONFLICT (user_id, tipo_documento) 
                DO UPDATE SET ruta_archivo_servidor = EXCLUDED.ruta_archivo_servidor
            """, (user_id, tipo, path))
            conn.commit()
        except Exception:
            conn.rollback() 
        
        cur.close()
        return jsonify({"status": "success", "message": f"{tipo} guardado correctamente"}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/verificar_estatus/<int:user_id>', methods=['GET'])
def verificar_estatus(user_id):
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT es_verificado FROM usuarios WHERE id = %s", (user_id,))
        resultado = cur.fetchone()
        cur.close()
        return jsonify({
            "status": "success", 
            "es_verificado": resultado['es_verificado'] if resultado else False
        }), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

# --- NUEVOS ENDPOINTS DE ASIGNACIÓN DE PEDIDOS ---

@app.route('/api/delivery/pedidos_disponibles', methods=['GET'])
def obtener_pedidos_delivery():
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT id, id_usuario AS cliente, direccion_entrega AS direccion, total 
            FROM pedidos 
            WHERE estado = 'listo_para_entrega' OR estado = 'pendiente'
        """)
        pedidos_listos = cur.fetchall()
        cur.close()
        return jsonify(pedidos_listos), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/pedidos_pendientes', methods=['GET'])
def pedidos_pendientes():
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT id, direccion_entrega, total 
            FROM pedidos 
            WHERE estado = 'pendiente'
        """)
        pedidos = cur.fetchall()
        cur.close()
        return jsonify(pedidos), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/aceptar_pedido', methods=['POST'])
def aceptar_pedido():
    data = request.json
    pedido_id = data.get('pedido_id')
    repartidor_id = data.get('repartidor_id')
    conn = None

    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT es_verificado FROM usuarios WHERE id = %s", (repartidor_id,))
        repartidor = cur.fetchone()
        
        if not repartidor:
            cur.close()
            return jsonify({"error": "Repartidor no encontrado"}), 404
            
        if not repartidor['es_verificado']:
            cur.close()
            return jsonify({
                "error": "Cuenta no verificada", 
                "mensaje": "Tu cuenta aún no ha sido aprobada por el administrador. No puedes aceptar pedidos."
            }), 403

        cur.execute("SELECT estado FROM pedidos WHERE id = %s", (pedido_id,))
        pedido = cur.fetchone()
        
        if not pedido:
            cur.close()
            return jsonify({"error": "Pedido no encontrado"}), 404
            
        if pedido['estado'] != 'pendiente' and pedido['estado'] != 'listo_para_entrega':
            cur.close()
            return jsonify({"error": "Este pedido ya fue tomado por otro repartidor"}), 400

        cur.execute("""
            UPDATE pedidos 
            SET repartidor_id = %s, estado = 'aceptado' 
            WHERE id = %s
        """, (repartidor_id, pedido_id))
        
        conn.commit()
        cur.close()
        return jsonify({"status": "success", "message": "¡Pedido aceptado con éxito!"}), 200
        
    except Exception as e:
        traceback.print_exc()
        if conn: conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(debug=True, host='0.0.0.0', port=port)