DROP DATABASE IF EXISTS ifbet;

CREATE DATABASE ifbet;

\c ifbet;

CREATE TABLE usuario (
    id serial primary key,
    nome character varying(200) not null,
    email character varying(200) unique not null,
    senha character varying(200) not null,
    saldo money default 0::money
);

INSERT INTO usuario (nome, email, senha, saldo) VALUES
('Gustavo', 'gugu@riogrande.ifrs.edu.br', md5('123'), 10000),
('Kelly Slater', 'kelly@riogrande.ifrs.edu.br', md5('123'), 15000),
('Gabriel Medina', 'medina@riogrande.ifrs.edu.br', md5('123'), 5000),
('Ronaldinho Gaucho', 'gaucho@riogrande.ifrs.edu.br', md5('123'), 3500);

CREATE TABLE equipe (
    id serial primary key,
    nome text,
    local text
);
INSERT INTO equipe (nome, local) VALUES
('SAO PAULO DE RG', 'ALDO DAPUZZO'),
('RIOGRANDENSE', 'COLOSSO DO TREVO'),
('CASSINO', 'CASSINAO'),
('VEM SUANDO QUE TE ENXUGO', 'AVENIDA'),
('GREMIO', 'OLIMPICO'),
('RIO GRANDE', 'ARTUR LAWSON');

CREATE TABLE jogo (
    id serial primary key,
    data_hora timestamp default current_timestamp,
    equipe_casa_id integer references equipe (id),
    equipe_visitante_id integer references equipe(id),
    gols_da_casa integer,
    gols_do_visitante integer
);
INSERT INTO jogo (equipe_casa_id, equipe_visitante_id) VALUES
(1, 6),
(2, 5),
(3, 4),
(5, 1), 
(6, 2), 
(4, 3), 
(1, 3),
(2, 4),
(5, 6);

CREATE TABLE aposta (
    id serial primary key,
    usuario_id integer references usuario (id),
    valor money,
    jogo_id integer references jogo (id),
    gols_da_casa integer,
    gols_do_visitante integer,
    odd real check (odd >= 0 and odd <= 1) 
);

INSERT INTO aposta (usuario_id, valor, jogo_id, gols_da_casa, gols_do_visitante, odd) VALUES
(1, 100, 1, 4, 0, 0.5),
(2, 50, 3, 3, 1, 0.5),
(3, 70, 6, 1, 5, 0.5),
(4, 600, 9, 3, 4, 0.5);

UPDATE usuario SET saldo = CAST((saldo::numeric - 100::numeric) as money) WHERE id = 2;


--DROP FUNCTION propor_aposta;

CREATE FUNCTION propor_aposta(var_usuario_id integer, var_jogo_id integer, var_valor money) RETURNS BOOLEAN AS
$$
DECLARE
    param_saldo money;
    
    nome_equipe_casa text;
    nome_equipe_visitante text; 
    
    param_equipe_casa_id integer := 0;
    param_equipe_visitante_id integer := 0;
    
    param_odd real := CAST(RANDOM() AS NUMERIC(3,2));
    
    gols_casa integer := CAST(RANDOM()*10 AS NUMERIC(1,0));
    gols_visitante integer := CAST(RANDOM()*10 AS NUMERIC(1,0));    
    
BEGIN
    SELECT equipe_casa_id, equipe_visitante_id FROM jogo WHERE id = var_jogo_id INTO param_equipe_casa_id, param_equipe_visitante_id;
    
    SELECT nome FROM equipe WHERE id = param_equipe_casa_id INTO nome_equipe_casa;
    
    SELECT nome FROM equipe WHERE id = param_equipe_visitante_id INTO nome_equipe_visitante;
            
    SELECT saldo::money FROM usuario where id = var_usuario_id INTO param_saldo;        
            
    IF (var_valor::numeric <= param_saldo::numeric) THEN
    
        RAISE NOTICE '% (%) vs % (%): Aposta: %, ODD:%', nome_equipe_casa, gols_casa, nome_equipe_visitante, gols_visitante, var_valor, param_odd;        
           
         INSERT INTO aposta (usuario_id, valor, jogo_id, gols_da_casa, gols_do_visitante, odd) VALUES
    (var_usuario_id, var_valor, var_jogo_id, gols_casa, gols_visitante, param_odd);
    
        UPDATE usuario SET saldo = cast((saldo::numeric - var_valor::numeric) as money) where id = var_usuario_id;
    
        RETURN TRUE;
    
    ELSE
        RAISE NOTICE 'saldo insuficiente';    
    END IF;    
    
    RETURN FALSE;
    
 END;
$$ LANGUAGE 'plpgsql';

-- 1
-- 
CREATE OR REPLACE FUNCTION obter_saldo(var_usuario_id integer) RETURNS money AS
$$
DECLARE 
    saldo_atual money := 0::money;
BEGIN
    SELECT saldo FROM usuario WHERE id = var_usuario_id INTO saldo_atual;
    RETURN saldo_atual;
END;
$$ LANGUAGE 'plpgsql';

-- 2
CREATE OR REPLACE FUNCTION quantidade_apostas(var_usuario_id integer) RETURNS integer AS
$$
DECLARE 
    qtde_apostas integer := 0;
BEGIN
    SELECT count(*) FROM aposta WHERE usuario_id = var_usuario_id INTO qtde_apostas;
    RETURN qtde_apostas;
END;
$$ LANGUAGE 'plpgsql';

-- 3
CREATE OR REPLACE FUNCTION valor_total_apostado(var_usuario_id integer) RETURNS money AS
$$
DECLARE 
    valor_total money := 0::money;
BEGIN
    SELECT sum(valor) FROM aposta WHERE usuario_id = var_usuario_id INTO valor_total;
    RETURN valor_total;
END;
$$ LANGUAGE 'plpgsql';


-- cuidar: como saber se ganhou e qto ganhou? odd * valor_aposta = mas neste, devemos verificar se o resultado bate

-- 4
CREATE OR REPLACE FUNCTION nome_equipe(var_equipe_id integer) RETURNS text AS 
$$
DECLARE
    resultado text;
BEGIN
    SELECT nome FROM equipe WHERE id = var_equipe_id INTO resultado;
    RETURN resultado;
END;
$$ LANGUAGE 'plpgsql';

-- 5
CREATE OR REPLACE FUNCTION nome_jogo(var_jogo_id integer) RETURNS text AS
$$
DECLARE
    resultado_casa text;
    resultado_visitante text;
BEGIN
    SELECT nome FROM equipe JOIN jogo ON equipe.id = jogo.equipe_casa_id WHERE jogo.id = var_jogo_id INTO resultado_casa;
    
    SELECT nome FROM equipe JOIN jogo ON equipe.id = jogo.equipe_visitante_id WHERE jogo.id = var_jogo_id INTO resultado_visitante;
    
    RETURN resultado_casa || ' x ' || resultado_visitante;
END;
$$ LANGUAGE 'plpgsql';

-- 6
CREATE OR REPLACE FUNCTION possui_saldo(var_usuario_id integer) RETURNS BOOLEAN AS
$$
DECLARE
    saldo_atual money := 0::money;
BEGIN
    saldo_atual := obter_saldo(var_usuario_id);
    IF (saldo_atual IS NULL OR saldo_atual <= 0::money) THEN
        RETURN FALSE;
    END IF;
    RETURN TRUE;
END;
$$ LANGUAGE 'plpgsql';

-- 7
CREATE OR REPLACE FUNCTION total_usuarios() RETURNS INTEGER AS
$$
DECLARE
    total integer := 0;
BEGIN
    select count(*) FROM usuario INTO total;
    RETURN total;
END;
$$ LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION total_equipes() RETURNS INTEGER AS
$$
DECLARE
    total integer := 0;
BEGIN
    select count(*) FROM equipe INTO total;
    RETURN total;
END;
$$ LANGUAGE 'plpgsql';



CREATE OR REPLACE FUNCTION total_jogos() RETURNS INTEGER AS
$$
DECLARE
    total integer := 0;
BEGIN
    select count(*) FROM jogo INTO total;
    RETURN total;
END;
$$ LANGUAGE 'plpgsql';

-- 10

CREATE OR REPLACE FUNCTION media_valor_apostas() RETURNS money AS
$$
DECLARE
    media money := 0::money;
BEGIN
    select avg(valor::numeric) FROM aposta INTO media;
    RETURN media;
END;
$$ LANGUAGE 'plpgsql';


-- 11
CREATE OR REPLACE FUNCTION usuario_mais_rico() RETURNS money AS
$$
DECLARE
    maior_saldo money := 0::money;
BEGIN
    select MAX(saldo) FROM usuario INTO maior_saldo;
    RETURN maior_saldo;
END;
$$ LANGUAGE 'plpgsql';


-- 12
CREATE OR REPLACE FUNCTION maior_aposta() RETURNS money AS
$$
DECLARE
    maior money := 0::money;
BEGIN
    select MAX(valor) FROM aposta INTO maior;
    RETURN maior;
END;
$$ LANGUAGE 'plpgsql';

-- 13
CREATE OR REPLACE FUNCTION apostas_usuario(var_usuario_id integer) RETURNS 
    TABLE (var_id integer, var_valor money, var_odd real) AS
$$
DECLARE
BEGIN
    RETURN QUERY SELECT id, valor, odd FROM aposta WHERE usuario_id = var_usuario_id; 
END;
$$ LANGUAGE 'plpgsql';

-- select * from apostas_usuario(1);

-- 14
-- Garante que o ID do jogo venha junto para montar o formulário
CREATE OR REPLACE FUNCTION liste_jogos() 
RETURNS TABLE (var_id integer, var_data_hora timestamp, var_equipe_casa text, var_equipe_visitante text) AS
$$
BEGIN
    RETURN QUERY 
    SELECT 
        j.id, 
        j.data_hora, 
        ec.nome AS equipe_casa, 
        ev.nome AS equipe_visitante 
    FROM jogo j
    JOIN equipe ec ON j.equipe_casa_id = ec.id
    JOIN equipe ev ON j.equipe_visitante_id = ev.id;
END;
$$ LANGUAGE 'plpgsql';


-- 15
-- Garante que o lucro seja calculado apenas para a aposta requisitada

CREATE OR REPLACE FUNCTION lucro_potencial(aposta_id integer) 
RETURNS TABLE (var_valor money, var_odd real, var_lucro money) AS
$$
BEGIN
    RETURN QUERY 
    SELECT valor, odd, (valor + (valor * CAST(odd AS numeric)))::money AS lucro 
    FROM aposta 
    WHERE id = aposta_id;
END;
$$ LANGUAGE 'plpgsql';

-- 16
DROP FUNCTION tempo_desde_jogo;
CREATE OR REPLACE FUNCTION tempo_desde_jogo(integer) RETURNS INTERVAL AS
$$
DECLARE
    var_tempo_decorrido INTERVAL := NULL;
BEGIN
    IF (EXISTS(SELECT * FROM jogo
     WHERE id = $1)) THEN
        SELECT AGE(CURRENT_TIMESTAMP, data_hora) AS tempo_decorrido FROM jogo WHERE id = $1 INTO var_tempo_decorrido;
    END IF;        
    RETURN var_tempo_decorrido;
END;
$$ LANGUAGE 'plpgsql';


-- 17
CREATE OR REPLACE FUNCTION saldo_total_sistema() RETURNS TABLE(var_saldo money) AS
$$
BEGIN
    RETURN QUERY SELECT COALESCE(SUM(saldo), 0::MONEY) FROM usuario;
END;
$$ LANGUAGE 'plpgsql';

--  id serial primary key,
--    usuario_id integer references usuario (id),
--    valor money,
--    jogo_id integer references jogo (id),
--    gols_da_casa integer,
--    gols_do_visitante integer,
--    odd real check (odd >= 0 and odd <= 1) 
--);

-- 18
--DROP FUNCTION apostas_acima;
CREATE OR REPLACE FUNCTION apostas_acima(param_valor numeric) RETURNS TABLE(var_valor money, var_gols_da_casa integer, var_gols_do_visitante integer, var_odd real) AS
$$
BEGIN
    RETURN QUERY SELECT valor, gols_da_casa, gols_do_visitante, odd FROM aposta WHERE valor::numeric > param_valor;
END;
$$ LANGUAGE 'plpgsql';

-- 19
CREATE OR REPLACE FUNCTION usuarios_sem_apostas() RETURNS TABLE(var_id integer, var_nome varchar, var_email varchar) AS
$$
BEGIN
    RETURN QUERY select id, nome, email from usuario where id not in (select usuario_id from aposta);
END;
$$ LANGUAGE 'plpgsql'; 

-- 20
DROP FUNCTION ranking_apostadores;
CREATE OR REPLACE FUNCTION ranking_apostadores() RETURNS TABLE(var_id integer, var_nome varchar, var_qtde bigint) AS
$$
BEGIN
    RETURN QUERY select usuario.id, usuario.nome, coalesce(count(aposta.id), 0) as qtde FROM usuario LEFT JOIN aposta ON usuario.id = aposta.usuario_id GROUP by usuario.id, usuario.nome, aposta.id ORDER BY usuario.id;
END;
$$ LANGUAGE 'plpgsql'; 

-- 21
CREATE OR REPLACE PROCEDURE depositar(var_usuario_id integer, var_valor money) AS 
$$
BEGIN
    UPDATE usuario SET saldo = saldo + var_valor WHERE id = var_usuario_id;
END;
$$ LANGUAGE 'plpgsql';  


-- 22
--Crie uma procedure sacar(usuario_id, valor).
--
--Regras:
--
--verificar saldo;
--impedir saldo negativo.
CREATE OR REPLACE PROCEDURE sacar(var_usuario_id integer, var_valor money) AS 
$$
DECLARE
    var_saldo_atual money;
BEGIN
    UPDATE usuario SET saldo = CASE 
        WHEN (saldo - var_valor >= 0::money) THEN saldo - var_valor 
        ELSE saldo END 
    WHERE id = var_usuario_id;
    
    SELECT saldo FROM usuario WHERE id = var_usuario_id INTO var_saldo_atual;
    
    RAISE NOTICE 'Saldo Atual: %', var_saldo_atual;   
    
END;
$$ LANGUAGE 'plpgsql';  

-- 23
CREATE OR REPLACE PROCEDURE transferir(var_usuario_id_origem integer, var_usuario_id_destino integer, var_valor money) AS 
$$
DECLARE
    var_saldo_origem money;
BEGIN
    -- existe os 2 usuarios
    IF (EXISTS(SELECT * FROM usuario WHERE id = var_usuario_id_origem) AND EXISTS(SELECT * FROM usuario WHERE id = var_usuario_id_destino)) THEN
    
       -- tem saldo suficiente     
       SELECT COALESCE(saldo, 0::MONEY) FROM usuario WHERE id = var_usuario_id_origem INTO var_saldo_origem;
       IF ((var_saldo_origem - var_valor) >= 0::money) THEN                    
       
            CALL sacar(var_usuario_id_origem, var_valor);
            CALL depositar(var_usuario_id_destino, var_valor);
            
       END IF;    
    END IF;   
END;
$$ LANGUAGE 'plpgsql';  

-- 24
CREATE OR REPLACE FUNCTION cadastrar_equipe(var_nome text, var_local text) RETURNS integer AS 
$$
DECLARE
    var_id integer := 0;
BEGIN   
    INSERT INTO equipe (nome, local) VALUES(var_nome, var_local) RETURNING id INTO var_id;
    RETURN var_id;
END;
$$ LANGUAGE 'plpgsql';  
