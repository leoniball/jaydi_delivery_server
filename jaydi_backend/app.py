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
# CORS habilitado para que tu App de Flutter y tu Panel Web se conecten sin bloqueos
CORS(app)

# --- CONFIGURACIÓN DE BASE DE DATOS (NEON) ---
DB_URL = os.environ.get('DATABASE_URL', '')

def get_db_connection():
    return psycopg2.connect(
        DB_URL,
        keepalives=1,
        keepalives_idle=60,      # Mantiene la conexión viva (Ideal para plan de pago)
        keepalives_interval=10,
        keepalives_count=5,
        connect_timeout=10       # Evita que el server se cuelgue si la red falla
    )

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Asegúrate de configurar un "Disk" en Render apuntando a esta carpeta
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads', 'documentos')

# Límite de 16MB para subida de fotos de documentos
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# --- SERVIR ARCHIVOS ---
@app.route('/uploads/documentos/user_<int:user_id>/<filename>')
def ver_archivo(user_id, filename):
    directorio_usuario = os.path.join(UPLOAD_FOLDER, f"user_{user_id}")
    return send_from_directory(directorio_usuario, filename)

@app.route('/')
def index():
    return jsonify({
        "status": "online",
        "message": "Servidor de Jaydi Express funcionando en Render 🚀",
        "ambiente": "Producción - Paid Plan"
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
        cur.execute("""
            SELECT u.id, u.nombre, u.apellido, u.email, u.es_verificado, 
                   COALESCE(u.saldo_acumulado, 0) as saldo, 
                   u.ultima_conexion,
                   (SELECT json_agg(json_build_object('tipo', tipo_documento, 'ruta', ruta_archivo_servidor)) 
                    FROM documentos_repartidor WHERE user_id = u.id) as documentos
            FROM usuarios u
            WHERE u.rol = 'repartidor'
            ORDER BY u.es_verificado ASC, u.ultima_conexion DESC NULLS LAST
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
        if conn: conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

# --- ENDPOINTS PARA LA APP (FLUTTER) ---

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email', '').strip().lower() 
    password = data.get('password')
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT id, nombre, apellido, email, es_verificado, rol
            FROM usuarios 
            WHERE LOWER(email) = %s AND password = %s
        """, (email, password))
        
        user = cur.fetchone()
        
        if user:
            cur.execute("UPDATE usuarios SET ultima_conexion = CURRENT_TIMESTAMP WHERE id = %s", (user['id'],))
            conn.commit()
            return jsonify({
                "status": "success",
                "userData": {
                    "id": str(user['id']),
                    "nombre": user['nombre'],
                    "apellido": user['apellido'],
                    "email": user['email'],
                    "status": "aprobado" if user['es_verificado'] else "pendiente",
                    "es_verificado": user['es_verificado']
                }
            }), 200
        return jsonify({"status": "error", "error": "Credenciales inválidas"}), 401
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/registrar', methods=['POST'])
@app.route('/registro', methods=['POST'])
def registro():
    data = request.json
    nombre = data.get('nombre')
    apellido = data.get('apellido')
    email = data.get('email', '').strip().lower()
    password = data.get('password') 
    rol = data.get('rol', 'repartidor')
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT id FROM usuarios WHERE LOWER(email) = %s", (email,))
        if cur.fetchone():
            return jsonify({"status": "error", "error": "El email ya existe"}), 400
        
        cur.execute("""
            INSERT INTO usuarios (nombre, apellido, email, password, rol, es_verificado, saldo_acumulado, ultima_conexion)
            VALUES (%s, %s, %s, %s, %s, FALSE, 0.0, CURRENT_TIMESTAMP) 
            RETURNING id, nombre, apellido, email
        """, (nombre, apellido, email, password, rol))
        nuevo = cur.fetchone()
        conn.commit()
        
        return jsonify({
            "status": "success",
            "userData": {
                "id": str(nuevo['id']), 
                "nombre": nuevo['nombre'], 
                "apellido": nuevo['apellido'], 
                "email": nuevo['email'],
                "status": "pendiente"
            }
        }), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "error": str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/perfil/<int:user_id>', methods=['GET', 'PUT'])
@app.route('/perfil/<int:user_id>', methods=['GET', 'PUT'])
def gestionar_perfil(user_id):
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        if request.method == 'GET':
            cur.execute("""
                SELECT id, nombre, apellido, email, telefono, vehiculo, placa, viajes_completados, 
                       COALESCE(saldo_acumulado, 0) as saldo, foto_perfil, es_verificado 
                FROM usuarios WHERE id = %s
            """, (user_id,))
            user = cur.fetchone()
            if not user:
                return jsonify({"status": "error", "error": "Usuario no encontrado"}), 404
            
            user['id'] = str(user['id']) # Para Flutter
            user['status'] = "aprobado" if user['es_verificado'] else "pendiente"
            return jsonify(user), 200

        if request.method == 'PUT':
            data = request.json
            fields = ['nombre', 'apellido', 'telefono', 'vehiculo', 'placa', 'foto_perfil']
            update_parts = []
            values = []
            for f in fields:
                if f in data:
                    update_parts.append(f"{f} = %s")
                    values.append(data[f])
            
            if update_parts:
                values.append(user_id)
                cur.execute(f"UPDATE usuarios SET {', '.join(update_parts)} WHERE id = %s", tuple(values))
                conn.commit()
            return jsonify({"status": "success", "message": "Perfil actualizado"}), 200

    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "error": str(e)}), 500
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

        ruta_publica = f"/uploads/documentos/user_{user_id}/{filename}"

        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO documentos_repartidor (user_id, tipo_documento, ruta_archivo_servidor)
            VALUES (%s, %s, %s)
            ON CONFLICT (user_id, tipo_documento) 
            DO UPDATE SET ruta_archivo_servidor = EXCLUDED.ruta_archivo_servidor
        """, (user_id, tipo, ruta_publica))
        conn.commit()
        return jsonify({"status": "success", "message": f"{tipo} guardado"}), 200
    except Exception as e:
        if conn: conn.rollback()
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
        res = cur.fetchone()
        return jsonify({
            "status": "success", 
            "es_verificado": res['es_verificado'] if res else False,
            "user_status": "aprobado" if res and res['es_verificado'] else "pendiente"
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/delivery/pedidos_disponibles', methods=['GET'])
def obtener_pedidos_delivery():
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT id, id_usuario AS cliente, direccion_entrega AS direccion, total 
            FROM pedidos 
            WHERE estado IN ('listo_para_entrega', 'pendiente')
        """)
        pedidos = cur.fetchall()
        return jsonify(pedidos), 200
    except Exception as e:
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
        rep = cur.fetchone()
        if not rep or not rep['es_verificado']:
            return jsonify({"status": "error", "error": "Cuenta no verificada"}), 403

        cur.execute("""
            UPDATE pedidos SET repartidor_id = %s, estado = 'aceptado' 
            WHERE id = %s AND estado IN ('pendiente', 'listo_para_entrega')
            RETURNING id
        """, (repartidor_id, pedido_id))
        ok = cur.fetchone()
        conn.commit()
        if ok:
            return jsonify({"status": "success", "message": "¡Pedido aceptado!"}), 200
        return jsonify({"status": "error", "error": "Pedido ya no disponible"}), 400
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "error": str(e)}), 500
    finally:
        if conn: conn.close()

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)