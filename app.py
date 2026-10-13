
import psycopg
from psycopg.rows import dict_row
from flask import Flask, render_template, request, redirect, url_for, flash

app = Flask(__name__)
app.secret_key = 'ifbet_secret_chave_segura'

# Configure com as credenciais do seu PostgreSQL local
DB_CONFIG = {
    "dbname": "ifbet",
    "user": "postgres",
    "password": "postgres", 
    "host": "localhost",
    "port": "5432"
}

def get_db_connection():
    # Retorna registros em formato de dicionário (chave-valor)
    return psycopg.connect(**DB_CONFIG, row_factory=dict_row)

@app.route('/dashboard')
def dashboard():
    usuario_id = request.args.get('id', default=1, type=int)
    
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            # Buscar dados do usuário
            cur.execute("SELECT nome FROM usuario WHERE id = %s;", (usuario_id,))
            user_data = cur.fetchone()
            nome_usuario = user_data['nome'] if user_data else "Usuário"

            # 1. Saldo do usuário via função SQL
            cur.execute("SELECT obter_saldo(%s) AS saldo;", (usuario_id,))
            saldo = cur.fetchone()['saldo']

            # 2. Lista de partidas
            cur.execute("SELECT * FROM liste_jogos();")
            jogos = cur.fetchall()

            # 3. Estatísticas gerais
            cur.execute("SELECT total_jogos() AS total;")
            total_jogos_sistema = cur.fetchone()['total']

            cur.execute("SELECT media_valor_apostas() AS media;")
            media_apostas = cur.fetchone()['media']

    return render_template(
        'dashboard.html',
        usuario_id=usuario_id,
        nome_usuario=nome_usuario,
        saldo=saldo,
        jogos=jogos,
        total_jogos=total_jogos_sistema,
        media_apostas=media_apostas
    )

@app.route('/apostar', methods=['POST'])
def apostar():
    usuario_id = request.form.get('usuario_id', type=int)
    jogo_id = request.form.get('jogo_id', type=int)
    valor = request.form.get('valor', type=str)

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            # Chamada direta da procedure/função propor_aposta
            cur.execute(
                "SELECT propor_aposta(%s, %s, %s::numeric::money) AS sucesso;",
                (usuario_id, jogo_id, valor)
            )
            resultado = cur.fetchone()['sucesso']
            conn.commit()

    if resultado:
        flash("Aposta realizada com sucesso!", "success")
    else:
        flash("Saldo insuficiente para realizar a aposta.", "danger")

    return redirect(url_for('dashboard', id=usuario_id))

@app.route('/meus-bilhetes')
def meus_bilhetes():
    usuario_id = request.args.get('id', default=1, type=int)
    bilhetes_completos = []

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            # Busca apostas do usuário
            cur.execute("SELECT * FROM apostas_usuario(%s);", (usuario_id,))
            apostas = cur.fetchall()

            # Subconsulta para calcular o lucro potencial de cada uma
            for aposta in apostas:
                cur.execute("SELECT * FROM lucro_potencial(%s);", (aposta['var_id'],))
                detalhe_lucro = cur.fetchone()
                
                bilhetes_completos.append({
                    'id': aposta['var_id'],
                    'valor': aposta['var_valor'],
                    'odd': aposta['var_odd'],
                    'lucro': detalhe_lucro['var_lucro'] if detalhe_lucro else 'R$ 0,00'
                })

    return render_template(
        'meus_bilhetes.html',
        usuario_id=usuario_id,
        bilhetes=bilhetes_completos
    )

if __name__ == '__main__':
    app.run(debug=True)