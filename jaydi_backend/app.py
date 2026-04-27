from flask import Flask, request, jsonify, render_template, send_from_directory
from flask_cors import CORS
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime

app = Flask(__name__)
CORS(app)

# --- CONFIGURACIÓN DE BASE DE DATOS (NEON) ---
DB_URL = "postgresql://neondb_owner:npg_hF4PjcEJq5RO@ep-jolly-waterfall-amgwvrji-pooler.c-5.us-east-1.aws.neon.tech/neondb?sslmode=require"

def get_db_connection():
    return psycopg2.connect(DB_URL)

# RUTA CRÍTICA: Definimos la ruta absoluta para que Flask no se pierda buscando archivos
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
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT id, nombre, correo, es_verificado, 
                   COALESCE(saldo_acumulado, 0) as saldo, 
                   ultima_conexion 
            FROM usuarios 
            WHERE tipo_usuario = 'repartidor'
            ORDER BY es_verificado ASC, ultima_conexion DESC NULLS LAST
        """)
        repartidores = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify(repartidores), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/admin/aprobar/<int:user_id>', methods=['POST', 'GET'])
def aprobar_repartidor(user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("UPDATE usuarios SET es_verificado = TRUE WHERE id = %s", (user_id,))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "success", "message": "Repartidor aprobado"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- ENDPOINTS PARA LA APP (FLUTTER) ---

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    correo = data.get('correo')
    clave = data.get('clave')
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        ahora = datetime.now()
        cur.execute("""
            UPDATE usuarios 
            SET ultima_conexion = %s 
            WHERE correo = %s AND clave = %s 
            RETURNING id, nombre, correo, es_verificado
        """, (ahora, correo, clave))
        
        user = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        
        if user:
            return jsonify({
                "status": "success",
                "userData": {
                    "id": str(user['id']),
                    "nombre": user['nombre'],
                    "correo": user['correo'],
                    "verificado": user['es_verificado']
                }
            }), 200
        return jsonify({"error": "Credenciales inválidas"}), 401
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/registro', methods=['POST'])
def registro():
    data = request.json
    nombre = data.get('nombre')
    correo = data.get('correo')
    clave = data.get('clave') 
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT id FROM usuarios WHERE correo = %s", (correo,))
        if cur.fetchone():
            return jsonify({"error": "El correo ya existe"}), 409
        
        cur.execute("""
            INSERT INTO usuarios (nombre, correo, clave, tipo_usuario, es_verificado, saldo_acumulado, ultima_conexion)
            VALUES (%s, %s, %s, 'repartidor', FALSE, 0.0, CURRENT_TIMESTAMP) 
            RETURNING id, nombre, correo
        """, (nombre, correo, clave))
        nuevo = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({
            "status": "success",
            "userData": {"id": str(nuevo['id']), "nombre": nuevo['nombre'], "correo": nuevo['correo']}
        }), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/subir_documento', methods=['POST'])
def subir_documento():
    if 'file' not in request.files:
        return jsonify({"error": "No hay archivo"}), 400
    
    file = request.files['file']
    user_id = request.form.get('user_id')
    tipo = request.form.get('tipo', 'documento')

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
        conn.close()

        return jsonify({"status": "success", "message": f"{tipo} guardado correctamente"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/verificar_estatus/<int:user_id>', methods=['GET'])
def verificar_estatus(user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT es_verificado FROM usuarios WHERE id = %s", (user_id,))
        resultado = cur.fetchone()
        cur.close()
        conn.close()
        return jsonify({
            "status": "success", 
            "es_verificado": resultado['es_verificado'] if resultado else False
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- NUEVOS ENDPOINTS DE ASIGNACIÓN DE PEDIDOS ---

@app.route('/pedidos_pendientes', methods=['GET'])
def pedidos_pendientes():
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        # Aquí consultamos los pedidos que aún no han sido aceptados (estado='pendiente')
        cur.execute("""
            SELECT id, direccion_entrega, total 
            FROM pedidos 
            WHERE estado = 'pendiente'
        """)
        pedidos = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify(pedidos), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/aceptar_pedido', methods=['POST'])
def aceptar_pedido():
    data = request.json
    pedido_id = data.get('pedido_id')
    repartidor_id = data.get('repartidor_id')

    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Primero, verificamos si el pedido sigue disponible
        cur.execute("SELECT estado FROM pedidos WHERE id = %s", (pedido_id,))
        pedido = cur.fetchone()
        
        if not pedido:
            cur.close()
            conn.close()
            return jsonify({"error": "Pedido no encontrado"}), 404
            
        if pedido['estado'] != 'pendiente':
            cur.close()
            conn.close()
            return jsonify({"error": "Este pedido ya fue tomado por otro repartidor"}), 400

        # Si está disponible, lo asignamos al repartidor y cambiamos el estado
        cur.execute("""
            UPDATE pedidos 
            SET repartidor_id = %s, estado = 'aceptado' 
            WHERE id = %s
        """, (repartidor_id, pedido_id))
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({"status": "success", "message": "¡Pedido aceptado con éxito!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Usamos os.environ para que funcione en Render
    port = int(os.environ.get("PORT", 5000))
    app.run(debug=True, host='0.0.0.0', port=port)