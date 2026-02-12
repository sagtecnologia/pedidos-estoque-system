-- DROP SCHEMA public;

CREATE SCHEMA public AUTHORIZATION pg_database_owner;

COMMENT ON SCHEMA public IS 'standard public schema';
-- public.empresa_config definição

-- Drop table

-- DROP TABLE public.empresa_config;

CREATE TABLE public.empresa_config ( id uuid DEFAULT gen_random_uuid() NOT NULL, nome_empresa varchar(200) NOT NULL, razao_social varchar(200) NULL, cnpj varchar(18) NULL, endereco text NULL, cidade varchar(100) NULL, estado varchar(2) NULL, cep varchar(9) NULL, telefone varchar(20) NULL, email varchar(100) NULL, website varchar(200) NULL, logo_url text NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, whatsapp_api_provider varchar(50) NULL, whatsapp_api_url text NULL, whatsapp_api_key text NULL, whatsapp_numero_origem varchar(20) NULL, whatsapp_instance_id varchar(100) NULL, inscricao_estadual varchar(20) NULL, inscricao_municipal varchar(20) NULL, regime_tributario varchar(1) DEFAULT '1'::character varying NULL, cnae varchar(10) NULL, codigo_municipio varchar(10) NULL, endereco_numero varchar(20) NULL, bairro varchar(100) NULL, logradouro varchar(200) NULL, complemento varchar(100) NULL, certificado_digital text NULL, senha_certificado text NULL, csc_id varchar(50) NULL, csc_token varchar(100) NULL, ambiente_nfe varchar(1) DEFAULT '2'::character varying NULL, serie_nfe varchar(5) DEFAULT '1'::character varying NULL, proximo_numero_nfe int4 DEFAULT 1 NULL, cor_primaria varchar(7) DEFAULT '#3B82F6'::character varying NULL, cor_secundaria varchar(7) DEFAULT '#10B981'::character varying NULL, habilitar_cupom_fiscal bool DEFAULT false NULL, habilitar_nfce bool DEFAULT false NULL, alerta_estoque_minimo bool DEFAULT true NULL, dias_alerta_validade int4 DEFAULT 30 NULL, CONSTRAINT empresa_config_pkey PRIMARY KEY (id));

-- Column comments

COMMENT ON COLUMN public.empresa_config.whatsapp_api_provider IS 'Provedor da API: evolution, twilio, baileys, outro';
COMMENT ON COLUMN public.empresa_config.whatsapp_api_url IS 'URL base da API do WhatsApp';
COMMENT ON COLUMN public.empresa_config.whatsapp_api_key IS 'Token/Key de autenticação da API';
COMMENT ON COLUMN public.empresa_config.whatsapp_numero_origem IS 'Número de origem com DDI (ex: 5511999999999)';
COMMENT ON COLUMN public.empresa_config.whatsapp_instance_id IS 'ID da instância (usado em Evolution API)';

-- Table Triggers

create trigger empresa_config_updated_at before
update
    on
    public.empresa_config for each row execute function update_empresa_updated_at();

-- Permissions

ALTER TABLE public.empresa_config OWNER TO postgres;
GRANT ALL ON TABLE public.empresa_config TO postgres;
GRANT ALL ON TABLE public.empresa_config TO anon;
GRANT ALL ON TABLE public.empresa_config TO authenticated;
GRANT ALL ON TABLE public.empresa_config TO service_role;


-- public.estoque_movimentacoes_backup definição

-- Drop table

-- DROP TABLE public.estoque_movimentacoes_backup;

CREATE TABLE public.estoque_movimentacoes_backup ( id uuid NULL, produto_id uuid NULL, tipo varchar(10) NULL, quantidade numeric(10, 2) NULL, estoque_anterior numeric(10, 2) NULL, estoque_novo numeric(10, 2) NULL, pedido_id uuid NULL, usuario_id uuid NULL, observacao text NULL, created_at timestamptz NULL, sabor_id uuid NULL, preco_unitario numeric(10, 2) NULL, valor_total numeric(10, 2) NULL);

-- Permissions

ALTER TABLE public.estoque_movimentacoes_backup OWNER TO postgres;
GRANT ALL ON TABLE public.estoque_movimentacoes_backup TO postgres;
GRANT ALL ON TABLE public.estoque_movimentacoes_backup TO anon;
GRANT ALL ON TABLE public.estoque_movimentacoes_backup TO authenticated;
GRANT ALL ON TABLE public.estoque_movimentacoes_backup TO service_role;


-- public.cancelamento_pedidos definição

-- Drop table

-- DROP TABLE public.cancelamento_pedidos;

CREATE TABLE public.cancelamento_pedidos ( id uuid DEFAULT uuid_generate_v4() NOT NULL, pedido_id uuid NOT NULL, status_anterior varchar(20) NOT NULL, status_novo varchar(20) NOT NULL, motivo text NULL, cancelado_por uuid NOT NULL, pode_reverter bool DEFAULT true NULL, data_cancelamento timestamptz DEFAULT now() NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT cancelamento_pedidos_pkey PRIMARY KEY (id));
CREATE INDEX idx_cancelamento_data ON public.cancelamento_pedidos USING btree (data_cancelamento DESC);
CREATE INDEX idx_cancelamento_pedido_id ON public.cancelamento_pedidos USING btree (pedido_id);
CREATE INDEX idx_cancelamento_usuario ON public.cancelamento_pedidos USING btree (cancelado_por);

-- Permissions

ALTER TABLE public.cancelamento_pedidos OWNER TO postgres;
GRANT ALL ON TABLE public.cancelamento_pedidos TO postgres;
GRANT ALL ON TABLE public.cancelamento_pedidos TO anon;
GRANT ALL ON TABLE public.cancelamento_pedidos TO authenticated;
GRANT ALL ON TABLE public.cancelamento_pedidos TO service_role;


-- public.clientes definição

-- Drop table

-- DROP TABLE public.clientes;

CREATE TABLE public.clientes ( id uuid DEFAULT uuid_generate_v4() NOT NULL, nome varchar(255) NOT NULL, cpf_cnpj varchar(18) NULL, tipo varchar(10) NULL, contato varchar(255) NULL, whatsapp varchar(20) NULL, email varchar(255) NULL, endereco text NULL, cidade varchar(100) NULL, estado varchar(2) NULL, cep varchar(10) NULL, active bool DEFAULT true NULL, created_by uuid NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT clientes_cpf_cnpj_key UNIQUE (cpf_cnpj), CONSTRAINT clientes_pkey PRIMARY KEY (id), CONSTRAINT clientes_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['FISICA'::character varying, 'JURIDICA'::character varying])::text[]))));
CREATE INDEX idx_clientes_active ON public.clientes USING btree (active);
CREATE INDEX idx_clientes_cpf_cnpj ON public.clientes USING btree (cpf_cnpj);
CREATE INDEX idx_clientes_nome ON public.clientes USING btree (nome);

-- Table Triggers

create trigger update_clientes_updated_at before
update
    on
    public.clientes for each row execute function update_updated_at_column();

-- Permissions

ALTER TABLE public.clientes OWNER TO postgres;
GRANT ALL ON TABLE public.clientes TO postgres;
GRANT ALL ON TABLE public.clientes TO anon;
GRANT ALL ON TABLE public.clientes TO authenticated;
GRANT ALL ON TABLE public.clientes TO service_role;


-- public.estoque_movimentacoes definição

-- Drop table

-- DROP TABLE public.estoque_movimentacoes;

CREATE TABLE public.estoque_movimentacoes ( id uuid DEFAULT uuid_generate_v4() NOT NULL, produto_id uuid NOT NULL, tipo varchar(10) NOT NULL, quantidade numeric(10, 2) NOT NULL, estoque_anterior numeric(10, 2) NOT NULL, estoque_novo numeric(10, 2) NOT NULL, pedido_id uuid NULL, usuario_id uuid NOT NULL, observacao text NULL, created_at timestamptz DEFAULT now() NULL, sabor_id uuid NULL, preco_unitario numeric(10, 2) DEFAULT NULL::numeric NULL, valor_total numeric(10, 2) GENERATED ALWAYS AS ((quantidade * preco_unitario)) STORED NULL, CONSTRAINT estoque_movimentacoes_pkey PRIMARY KEY (id), CONSTRAINT estoque_movimentacoes_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['ENTRADA'::character varying, 'SAIDA'::character varying])::text[]))));
CREATE INDEX idx_estoque_mov_created_at ON public.estoque_movimentacoes USING btree (created_at DESC);
CREATE INDEX idx_estoque_mov_pedido ON public.estoque_movimentacoes USING btree (pedido_id);
CREATE INDEX idx_estoque_mov_preco ON public.estoque_movimentacoes USING btree (preco_unitario);
CREATE INDEX idx_estoque_mov_produto ON public.estoque_movimentacoes USING btree (produto_id);
CREATE INDEX idx_estoque_mov_sabor ON public.estoque_movimentacoes USING btree (sabor_id);
CREATE INDEX idx_estoque_mov_valor_total ON public.estoque_movimentacoes USING btree (valor_total);
CREATE UNIQUE INDEX idx_movimentacao_cancelamento_unica ON public.estoque_movimentacoes USING btree (pedido_id, produto_id, COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::uuid)) WHERE ((pedido_id IS NOT NULL) AND (observacao ~~ '%Cancelamento%'::text));
COMMENT ON INDEX public.idx_movimentacao_cancelamento_unica IS 'Garante que cada pedido tenha apenas UMA movimentação de CANCELAMENTO por produto/sabor.
Permite cancelar pedidos que já foram finalizados sem conflitar com as movimentações de finalização.';
CREATE UNIQUE INDEX "idx_movimentacao_finalização_unica" ON public.estoque_movimentacoes USING btree (pedido_id, produto_id, COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::uuid)) WHERE ((pedido_id IS NOT NULL) AND ((observacao ~~ '%Finalização%'::text) OR (observacao ~~ '%finalização%'::text)));
COMMENT ON INDEX public.idx_movimentacao_finalização_unica IS 'Garante que cada pedido tenha apenas UMA movimentação de FINALIZAÇÃO por produto/sabor. 
Previne duplicações causadas por sessões expiradas, cliques duplos ou retry de rede.';

-- Permissions

ALTER TABLE public.estoque_movimentacoes OWNER TO postgres;
GRANT ALL ON TABLE public.estoque_movimentacoes TO postgres;
GRANT ALL ON TABLE public.estoque_movimentacoes TO anon;
GRANT ALL ON TABLE public.estoque_movimentacoes TO authenticated;
GRANT ALL ON TABLE public.estoque_movimentacoes TO service_role;


-- public.estoque_reprocessamento_log definição

-- Drop table

-- DROP TABLE public.estoque_reprocessamento_log;

CREATE TABLE public.estoque_reprocessamento_log ( id uuid DEFAULT uuid_generate_v4() NOT NULL, produto_id uuid NULL, codigo_produto varchar(50) NULL, nome_produto varchar(255) NULL, estoque_anterior numeric(10, 2) NULL, estoque_recalculado numeric(10, 2) NULL, diferenca numeric(10, 2) NULL, total_entradas numeric(10, 2) NULL, total_saidas numeric(10, 2) NULL, movimentacoes_duplicadas_removidas int4 NULL, reprocessado_em timestamptz DEFAULT now() NULL, CONSTRAINT estoque_reprocessamento_log_pkey PRIMARY KEY (id));

-- Permissions

ALTER TABLE public.estoque_reprocessamento_log OWNER TO postgres;
GRANT ALL ON TABLE public.estoque_reprocessamento_log TO postgres;
GRANT ALL ON TABLE public.estoque_reprocessamento_log TO anon;
GRANT ALL ON TABLE public.estoque_reprocessamento_log TO authenticated;
GRANT ALL ON TABLE public.estoque_reprocessamento_log TO service_role;


-- public.fornecedores definição

-- Drop table

-- DROP TABLE public.fornecedores;

CREATE TABLE public.fornecedores ( id uuid DEFAULT uuid_generate_v4() NOT NULL, nome varchar(255) NOT NULL, cnpj varchar(18) NULL, contato varchar(255) NULL, whatsapp varchar(20) NULL, email varchar(255) NULL, endereco text NULL, active bool DEFAULT true NULL, created_by uuid NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, inscricao_estadual varchar(20) NULL, site varchar(200) NULL, banco varchar(100) NULL, agencia varchar(20) NULL, conta varchar(30) NULL, pix varchar(100) NULL, observacoes text NULL, CONSTRAINT fornecedores_cnpj_key UNIQUE (cnpj), CONSTRAINT fornecedores_pkey PRIMARY KEY (id));
CREATE INDEX idx_fornecedores_active ON public.fornecedores USING btree (active);
CREATE INDEX idx_fornecedores_cnpj ON public.fornecedores USING btree (cnpj);

-- Table Triggers

create trigger update_fornecedores_updated_at before
update
    on
    public.fornecedores for each row execute function update_updated_at_column();

-- Permissions

ALTER TABLE public.fornecedores OWNER TO postgres;
GRANT ALL ON TABLE public.fornecedores TO postgres;
GRANT ALL ON TABLE public.fornecedores TO anon;
GRANT ALL ON TABLE public.fornecedores TO authenticated;
GRANT ALL ON TABLE public.fornecedores TO service_role;


-- public.importacao_xml_log definição

-- Drop table

-- DROP TABLE public.importacao_xml_log;

CREATE TABLE public.importacao_xml_log ( id uuid DEFAULT uuid_generate_v4() NOT NULL, arquivo_nome varchar(255) NOT NULL, chave_nfe varchar(44) NULL, numero_nfe varchar(20) NULL, fornecedor_id uuid NULL, fornecedor_cnpj varchar(18) NULL, fornecedor_nome varchar(255) NULL, pedido_id uuid NULL, total_produtos int4 DEFAULT 0 NULL, valor_total numeric(10, 2) DEFAULT 0 NULL, status varchar(20) DEFAULT 'PROCESSANDO'::character varying NULL, erro_mensagem text NULL, created_by uuid NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT importacao_xml_log_pkey PRIMARY KEY (id), CONSTRAINT importacao_xml_log_status_check CHECK (((status)::text = ANY ((ARRAY['PROCESSANDO'::character varying, 'SUCESSO'::character varying, 'ERRO'::character varying, 'PARCIAL'::character varying])::text[]))));
CREATE INDEX idx_importacao_xml_log_chave ON public.importacao_xml_log USING btree (chave_nfe);
CREATE INDEX idx_importacao_xml_log_created ON public.importacao_xml_log USING btree (created_at DESC);
CREATE INDEX idx_importacao_xml_log_fornecedor ON public.importacao_xml_log USING btree (fornecedor_id);
CREATE INDEX idx_importacao_xml_log_pedido ON public.importacao_xml_log USING btree (pedido_id);
CREATE INDEX idx_importacao_xml_log_status ON public.importacao_xml_log USING btree (status);

-- Permissions

ALTER TABLE public.importacao_xml_log OWNER TO postgres;
GRANT ALL ON TABLE public.importacao_xml_log TO postgres;
GRANT ALL ON TABLE public.importacao_xml_log TO anon;
GRANT ALL ON TABLE public.importacao_xml_log TO authenticated;
GRANT ALL ON TABLE public.importacao_xml_log TO service_role;


-- public.pagamentos definição

-- Drop table

-- DROP TABLE public.pagamentos;

CREATE TABLE public.pagamentos ( id uuid DEFAULT uuid_generate_v4() NOT NULL, pedido_id uuid NOT NULL, valor numeric(10, 2) NOT NULL, forma_pagamento text NULL, observacao text NULL, usuario_id uuid NULL, created_at timestamp DEFAULT now() NULL, CONSTRAINT pagamentos_pkey PRIMARY KEY (id));
CREATE INDEX idx_pagamentos_pedido_id ON public.pagamentos USING btree (pedido_id);
COMMENT ON TABLE public.pagamentos IS 'Histórico de pagamentos recebidos dos pedidos';

-- Permissions

ALTER TABLE public.pagamentos OWNER TO postgres;
GRANT ALL ON TABLE public.pagamentos TO postgres;
GRANT ALL ON TABLE public.pagamentos TO anon;
GRANT ALL ON TABLE public.pagamentos TO authenticated;
GRANT ALL ON TABLE public.pagamentos TO service_role;


-- public.pedido_itens definição

-- Drop table

-- DROP TABLE public.pedido_itens;

CREATE TABLE public.pedido_itens ( id uuid DEFAULT uuid_generate_v4() NOT NULL, pedido_id uuid NOT NULL, produto_id uuid NOT NULL, quantidade numeric(10, 2) NOT NULL, preco_unitario numeric(10, 2) NOT NULL, subtotal numeric(10, 2) GENERATED ALWAYS AS ((quantidade * preco_unitario)) STORED NULL, created_at timestamptz DEFAULT now() NULL, sabor_id uuid NULL, conferido bool DEFAULT false NULL, conferido_por uuid NULL, data_conferencia timestamptz NULL, preco_compra_entrada numeric(10, 2) DEFAULT 0 NOT NULL, CONSTRAINT pedido_itens_pkey PRIMARY KEY (id));
CREATE INDEX idx_pedido_itens_conferido ON public.pedido_itens USING btree (conferido);
CREATE INDEX idx_pedido_itens_pedido ON public.pedido_itens USING btree (pedido_id);
CREATE INDEX idx_pedido_itens_preco_compra ON public.pedido_itens USING btree (preco_compra_entrada);
CREATE INDEX idx_pedido_itens_produto ON public.pedido_itens USING btree (produto_id);
CREATE INDEX idx_pedido_itens_sabor ON public.pedido_itens USING btree (sabor_id);

-- Column comments

COMMENT ON COLUMN public.pedido_itens.conferido IS 'Item foi conferido na separação';
COMMENT ON COLUMN public.pedido_itens.conferido_por IS 'Usuário que conferiu o item';
COMMENT ON COLUMN public.pedido_itens.data_conferencia IS 'Data/hora da conferência do item';
COMMENT ON COLUMN public.pedido_itens.preco_compra_entrada IS 'Valor de compra unitário no momento do pedido/entrada. Usado para análise de lucro precisa.';

-- Table Triggers

create trigger update_pedido_total_trigger after
insert
    or
delete
    or
update
    on
    public.pedido_itens for each row execute function update_pedido_total();

-- Permissions

ALTER TABLE public.pedido_itens OWNER TO postgres;
GRANT ALL ON TABLE public.pedido_itens TO postgres;
GRANT ALL ON TABLE public.pedido_itens TO anon;
GRANT ALL ON TABLE public.pedido_itens TO authenticated;
GRANT ALL ON TABLE public.pedido_itens TO service_role;


-- public.pedidos definição

-- Drop table

-- DROP TABLE public.pedidos;

CREATE TABLE public.pedidos ( id uuid DEFAULT uuid_generate_v4() NOT NULL, numero varchar(50) NOT NULL, solicitante_id uuid NOT NULL, fornecedor_id uuid NULL, status varchar(20) DEFAULT 'RASCUNHO'::character varying NOT NULL, total numeric(10, 2) DEFAULT 0 NULL, observacoes text NULL, aprovador_id uuid NULL, data_aprovacao timestamptz NULL, motivo_rejeicao text NULL, data_finalizacao timestamptz NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, tipo_pedido varchar(10) DEFAULT 'COMPRA'::character varying NULL, cliente_id uuid NULL, pagamento_status text DEFAULT 'PENDENTE'::text NULL, valor_pago numeric(10, 2) DEFAULT 0 NULL, valor_pendente numeric(10, 2) DEFAULT 0 NULL, data_pagamento_completo timestamp NULL, status_envio varchar(30) NULL, data_separacao timestamptz NULL, separado_por uuid NULL, data_despacho timestamptz NULL, despachado_por uuid NULL, CONSTRAINT pedidos_numero_key UNIQUE (numero), CONSTRAINT pedidos_pagamento_status_check CHECK ((pagamento_status = ANY (ARRAY['PENDENTE'::text, 'PARCIAL'::text, 'PAGO'::text]))), CONSTRAINT pedidos_pkey PRIMARY KEY (id), CONSTRAINT pedidos_status_check CHECK (((status)::text = ANY ((ARRAY['RASCUNHO'::character varying, 'ENVIADO'::character varying, 'APROVADO'::character varying, 'REJEITADO'::character varying, 'FINALIZADO'::character varying, 'CANCELADO'::character varying])::text[]))), CONSTRAINT pedidos_status_envio_check CHECK (((status_envio)::text = ANY ((ARRAY['AGUARDANDO_SEPARACAO'::character varying, 'SEPARADO'::character varying, 'DESPACHADO'::character varying])::text[]))), CONSTRAINT pedidos_tipo_pedido_check CHECK (((tipo_pedido)::text = ANY ((ARRAY['COMPRA'::character varying, 'VENDA'::character varying])::text[]))));
CREATE INDEX idx_pedidos_aprovador ON public.pedidos USING btree (aprovador_id);
CREATE INDEX idx_pedidos_cliente ON public.pedidos USING btree (cliente_id);
CREATE INDEX idx_pedidos_created_at ON public.pedidos USING btree (created_at DESC);
CREATE INDEX idx_pedidos_data_despacho ON public.pedidos USING btree (data_despacho);
CREATE INDEX idx_pedidos_data_separacao ON public.pedidos USING btree (data_separacao);
CREATE INDEX idx_pedidos_numero ON public.pedidos USING btree (numero);
CREATE INDEX idx_pedidos_pagamento_status ON public.pedidos USING btree (pagamento_status);
CREATE INDEX idx_pedidos_solicitante ON public.pedidos USING btree (solicitante_id);
CREATE INDEX idx_pedidos_status ON public.pedidos USING btree (status);
CREATE INDEX idx_pedidos_status_envio ON public.pedidos USING btree (status_envio);
CREATE INDEX idx_pedidos_tipo_pedido ON public.pedidos USING btree (tipo_pedido);
CREATE INDEX idx_pedidos_valor_pendente ON public.pedidos USING btree (valor_pendente);

-- Column comments

COMMENT ON COLUMN public.pedidos.pagamento_status IS 'Status do pagamento: PENDENTE, PARCIAL ou PAGO';
COMMENT ON COLUMN public.pedidos.valor_pago IS 'Valor total já pago pelo cliente';
COMMENT ON COLUMN public.pedidos.valor_pendente IS 'Valor ainda pendente de pagamento';
COMMENT ON COLUMN public.pedidos.data_pagamento_completo IS 'Data em que o pagamento foi quitado completamente';
COMMENT ON COLUMN public.pedidos.status_envio IS 'Status do fluxo logístico: AGUARDANDO_SEPARACAO, SEPARADO, DESPACHADO';
COMMENT ON COLUMN public.pedidos.data_separacao IS 'Data em que o pedido foi separado/conferido';
COMMENT ON COLUMN public.pedidos.separado_por IS 'Usuário que separou o pedido';
COMMENT ON COLUMN public.pedidos.data_despacho IS 'Data em que o pedido foi despachado/enviado';
COMMENT ON COLUMN public.pedidos.despachado_por IS 'Usuário que despachou o pedido';

-- Table Triggers

create trigger trigger_impedir_finalizar_cancelado before
update
    on
    public.pedidos for each row
    when ((((old.status)::text = 'CANCELADO'::text)
        and ((new.status)::text = 'FINALIZADO'::text))) execute function impedir_finalizar_cancelado();
create trigger update_pedidos_updated_at before
update
    on
    public.pedidos for each row execute function update_updated_at_column();

-- Permissions

ALTER TABLE public.pedidos OWNER TO postgres;
GRANT ALL ON TABLE public.pedidos TO postgres;
GRANT ALL ON TABLE public.pedidos TO anon;
GRANT ALL ON TABLE public.pedidos TO authenticated;
GRANT ALL ON TABLE public.pedidos TO service_role;


-- public.pre_pedido_itens definição

-- Drop table

-- DROP TABLE public.pre_pedido_itens;

CREATE TABLE public.pre_pedido_itens ( id uuid DEFAULT uuid_generate_v4() NOT NULL, pre_pedido_id uuid NOT NULL, produto_id uuid NOT NULL, sabor_id uuid NULL, quantidade numeric(10, 2) NOT NULL, preco_unitario numeric(10, 2) NOT NULL, subtotal numeric(10, 2) GENERATED ALWAYS AS ((quantidade * preco_unitario)) STORED NULL, estoque_disponivel_momento numeric(10, 2) NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT pre_pedido_itens_pkey PRIMARY KEY (id));
CREATE INDEX idx_pre_pedido_itens_pre_pedido ON public.pre_pedido_itens USING btree (pre_pedido_id);
CREATE INDEX idx_pre_pedido_itens_produto ON public.pre_pedido_itens USING btree (produto_id);
CREATE INDEX idx_pre_pedido_itens_sabor ON public.pre_pedido_itens USING btree (sabor_id);

-- Permissions

ALTER TABLE public.pre_pedido_itens OWNER TO postgres;
GRANT ALL ON TABLE public.pre_pedido_itens TO postgres;
GRANT ALL ON TABLE public.pre_pedido_itens TO anon;
GRANT ALL ON TABLE public.pre_pedido_itens TO authenticated;
GRANT ALL ON TABLE public.pre_pedido_itens TO service_role;


-- public.pre_pedidos definição

-- Drop table

-- DROP TABLE public.pre_pedidos;

CREATE TABLE public.pre_pedidos ( id uuid DEFAULT uuid_generate_v4() NOT NULL, numero varchar(50) NOT NULL, nome_solicitante varchar(255) NOT NULL, email_contato varchar(255) NULL, telefone_contato varchar(50) NULL, status varchar(20) DEFAULT 'PENDENTE'::character varying NOT NULL, total numeric(10, 2) DEFAULT 0 NULL, observacoes text NULL, token_publico varchar(100) NOT NULL, ip_origem varchar(50) NULL, user_agent text NULL, data_expiracao timestamptz NOT NULL, analisado_por uuid NULL, data_analise timestamptz NULL, cliente_vinculado_id uuid NULL, pedido_gerado_id uuid NULL, motivo_rejeicao text NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT pre_pedidos_numero_key UNIQUE (numero), CONSTRAINT pre_pedidos_pkey PRIMARY KEY (id), CONSTRAINT pre_pedidos_status_check CHECK (((status)::text = ANY ((ARRAY['PENDENTE'::character varying, 'EM_ANALISE'::character varying, 'APROVADO'::character varying, 'REJEITADO'::character varying, 'EXPIRADO'::character varying])::text[]))), CONSTRAINT pre_pedidos_token_publico_key UNIQUE (token_publico));
CREATE INDEX idx_pre_pedidos_created ON public.pre_pedidos USING btree (created_at DESC);
CREATE INDEX idx_pre_pedidos_expiracao ON public.pre_pedidos USING btree (data_expiracao);
CREATE INDEX idx_pre_pedidos_numero ON public.pre_pedidos USING btree (numero);
CREATE INDEX idx_pre_pedidos_status ON public.pre_pedidos USING btree (status);
CREATE INDEX idx_pre_pedidos_token ON public.pre_pedidos USING btree (token_publico);

-- Table Triggers

create trigger trigger_gerar_numero_pre_pedido before
insert
    on
    public.pre_pedidos for each row
    when (((new.numero is null)
        or ((new.numero)::text = ''::text))) execute function gerar_numero_pre_pedido();
create trigger trigger_update_pre_pedidos_updated_at before
update
    on
    public.pre_pedidos for each row execute function update_pre_pedidos_updated_at();

-- Permissions

ALTER TABLE public.pre_pedidos OWNER TO postgres;
GRANT ALL ON TABLE public.pre_pedidos TO postgres;
GRANT ALL ON TABLE public.pre_pedidos TO anon;
GRANT ALL ON TABLE public.pre_pedidos TO authenticated;
GRANT ALL ON TABLE public.pre_pedidos TO service_role;


-- public.produto_sabores definição

-- Drop table

-- DROP TABLE public.produto_sabores;

CREATE TABLE public.produto_sabores ( id uuid DEFAULT uuid_generate_v4() NOT NULL, produto_id uuid NOT NULL, sabor varchar(100) NOT NULL, quantidade numeric(10, 2) DEFAULT 0 NULL, ativo bool DEFAULT true NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT produto_sabores_pkey PRIMARY KEY (id), CONSTRAINT produto_sabores_produto_id_sabor_key UNIQUE (produto_id, sabor));
CREATE INDEX idx_produto_sabores_ativo ON public.produto_sabores USING btree (ativo);
CREATE INDEX idx_produto_sabores_produto ON public.produto_sabores USING btree (produto_id);
CREATE INDEX idx_produto_sabores_sabor ON public.produto_sabores USING btree (sabor);

-- Table Triggers

create trigger trigger_atualizar_estoque_produto after
insert
    or
delete
    or
update
    on
    public.produto_sabores for each row execute function atualizar_estoque_produto();
create trigger trigger_validar_estoque_sabor before
update
    on
    public.produto_sabores for each row execute function validar_estoque_sabor_nao_negativo();
create trigger update_produto_sabores_updated_at before
update
    on
    public.produto_sabores for each row execute function update_updated_at_column();

-- Permissions

ALTER TABLE public.produto_sabores OWNER TO postgres;
GRANT ALL ON TABLE public.produto_sabores TO postgres;
GRANT ALL ON TABLE public.produto_sabores TO anon;
GRANT ALL ON TABLE public.produto_sabores TO authenticated;
GRANT ALL ON TABLE public.produto_sabores TO service_role;


-- public.produtos definição

-- Drop table

-- DROP TABLE public.produtos;

CREATE TABLE public.produtos ( id uuid DEFAULT uuid_generate_v4() NOT NULL, codigo varchar(50) NOT NULL, nome varchar(255) NOT NULL, categoria varchar(100) NULL, unidade varchar(20) NOT NULL, estoque_atual numeric(10, 2) DEFAULT 0 NULL, estoque_minimo numeric(10, 2) DEFAULT 0 NULL, preco numeric(10, 2) DEFAULT 0 NULL, active bool DEFAULT true NULL, created_by uuid NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, preco_compra numeric(10, 2) DEFAULT 0 NULL, preco_venda numeric(10, 2) DEFAULT 0 NULL, marca varchar(100) NULL, codigo_barras varchar(50) NULL, sku varchar(50) NULL, descricao text NULL, cfop_venda varchar(10) DEFAULT '5102'::character varying NULL, cfop_compra varchar(10) DEFAULT '1102'::character varying NULL, volume_ml numeric(10, 2) NULL, embalagem varchar(50) NULL, quantidade_embalagem int4 DEFAULT 1 NULL, localizacao varchar(50) NULL, peso_kg numeric(10, 3) NULL, controla_validade bool DEFAULT false NULL, dias_alerta_validade int4 DEFAULT 30 NULL, marca_id uuid NULL, categoria_id uuid NULL, unidade_venda varchar(10) DEFAULT 'UN'::character varying NULL, preco_custo numeric(10, 2) NULL, estoque_maximo numeric(10, 2) DEFAULT 0 NULL, CONSTRAINT produtos_codigo_key UNIQUE (codigo), CONSTRAINT produtos_pkey PRIMARY KEY (id));
CREATE INDEX idx_produtos_active ON public.produtos USING btree (active);
CREATE INDEX idx_produtos_categoria ON public.produtos USING btree (categoria);
CREATE INDEX idx_produtos_codigo ON public.produtos USING btree (codigo);
CREATE INDEX idx_produtos_estoque_baixo ON public.produtos USING btree (estoque_atual) WHERE (estoque_atual <= estoque_minimo);
CREATE INDEX idx_produtos_marca ON public.produtos USING btree (marca);

-- Table Triggers

create trigger trigger_validar_estoque_nao_negativo before
update
    on
    public.produtos for each row execute function validar_estoque_nao_negativo();
create trigger update_produtos_updated_at before
update
    on
    public.produtos for each row execute function update_updated_at_column();

-- Permissions

ALTER TABLE public.produtos OWNER TO postgres;
GRANT ALL ON TABLE public.produtos TO postgres;
GRANT ALL ON TABLE public.produtos TO anon;
GRANT ALL ON TABLE public.produtos TO authenticated;
GRANT ALL ON TABLE public.produtos TO service_role;


-- public.users definição

-- Drop table

-- DROP TABLE public.users;

CREATE TABLE public.users ( id uuid NOT NULL, email varchar(255) NOT NULL, full_name varchar(255) NOT NULL, "role" varchar(20) NOT NULL, whatsapp varchar(20) NULL, active bool DEFAULT false NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT users_email_key UNIQUE (email), CONSTRAINT users_pkey PRIMARY KEY (id), CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['ADMIN'::character varying, 'COMPRADOR'::character varying, 'APROVADOR'::character varying, 'VENDEDOR'::character varying])::text[]))));
CREATE INDEX idx_users_active ON public.users USING btree (active);
CREATE INDEX idx_users_role ON public.users USING btree (role);

-- Column comments

COMMENT ON COLUMN public.users."role" IS 'Perfil do usuário: ADMIN (acesso total), GERENTE (operacional completo), VENDEDOR (vendas), COMPRADOR (pedidos), APROVADOR (aprovar pedidos)';

-- Table Triggers

create trigger update_users_updated_at before
update
    on
    public.users for each row execute function update_updated_at_column();

-- Permissions

ALTER TABLE public.users OWNER TO postgres;
GRANT ALL ON TABLE public.users TO postgres;
GRANT ALL ON TABLE public.users TO anon;
GRANT ALL ON TABLE public.users TO authenticated;
GRANT ALL ON TABLE public.users TO service_role;


-- public.cancelamento_pedidos chaves estrangeiras

ALTER TABLE public.cancelamento_pedidos ADD CONSTRAINT cancelamento_pedidos_cancelado_por_fkey FOREIGN KEY (cancelado_por) REFERENCES public.users(id);
ALTER TABLE public.cancelamento_pedidos ADD CONSTRAINT cancelamento_pedidos_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id) ON DELETE CASCADE;


-- public.clientes chaves estrangeiras

ALTER TABLE public.clientes ADD CONSTRAINT clientes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


-- public.estoque_movimentacoes chaves estrangeiras

ALTER TABLE public.estoque_movimentacoes ADD CONSTRAINT estoque_movimentacoes_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id) ON DELETE RESTRICT;
ALTER TABLE public.estoque_movimentacoes ADD CONSTRAINT estoque_movimentacoes_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);
ALTER TABLE public.estoque_movimentacoes ADD CONSTRAINT estoque_movimentacoes_sabor_id_fkey FOREIGN KEY (sabor_id) REFERENCES public.produto_sabores(id);
ALTER TABLE public.estoque_movimentacoes ADD CONSTRAINT estoque_movimentacoes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id);


-- public.estoque_reprocessamento_log chaves estrangeiras

ALTER TABLE public.estoque_reprocessamento_log ADD CONSTRAINT estoque_reprocessamento_log_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);


-- public.fornecedores chaves estrangeiras

ALTER TABLE public.fornecedores ADD CONSTRAINT fornecedores_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


-- public.importacao_xml_log chaves estrangeiras

ALTER TABLE public.importacao_xml_log ADD CONSTRAINT importacao_xml_log_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);
ALTER TABLE public.importacao_xml_log ADD CONSTRAINT importacao_xml_log_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id);
ALTER TABLE public.importacao_xml_log ADD CONSTRAINT importacao_xml_log_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id);


-- public.pagamentos chaves estrangeiras

ALTER TABLE public.pagamentos ADD CONSTRAINT pagamentos_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id) ON DELETE CASCADE;
ALTER TABLE public.pagamentos ADD CONSTRAINT pagamentos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id);


-- public.pedido_itens chaves estrangeiras

ALTER TABLE public.pedido_itens ADD CONSTRAINT pedido_itens_conferido_por_fkey FOREIGN KEY (conferido_por) REFERENCES public.users(id);
ALTER TABLE public.pedido_itens ADD CONSTRAINT pedido_itens_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id) ON DELETE RESTRICT;
ALTER TABLE public.pedido_itens ADD CONSTRAINT pedido_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);
ALTER TABLE public.pedido_itens ADD CONSTRAINT pedido_itens_sabor_id_fkey FOREIGN KEY (sabor_id) REFERENCES public.produto_sabores(id);


-- public.pedidos chaves estrangeiras

ALTER TABLE public.pedidos ADD CONSTRAINT pedidos_aprovador_id_fkey FOREIGN KEY (aprovador_id) REFERENCES public.users(id);
ALTER TABLE public.pedidos ADD CONSTRAINT pedidos_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);
ALTER TABLE public.pedidos ADD CONSTRAINT pedidos_despachado_por_fkey FOREIGN KEY (despachado_por) REFERENCES public.users(id);
ALTER TABLE public.pedidos ADD CONSTRAINT pedidos_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id);
ALTER TABLE public.pedidos ADD CONSTRAINT pedidos_separado_por_fkey FOREIGN KEY (separado_por) REFERENCES public.users(id);
ALTER TABLE public.pedidos ADD CONSTRAINT pedidos_solicitante_id_fkey FOREIGN KEY (solicitante_id) REFERENCES public.users(id);


-- public.pre_pedido_itens chaves estrangeiras

ALTER TABLE public.pre_pedido_itens ADD CONSTRAINT pre_pedido_itens_pre_pedido_id_fkey FOREIGN KEY (pre_pedido_id) REFERENCES public.pre_pedidos(id) ON DELETE CASCADE;
ALTER TABLE public.pre_pedido_itens ADD CONSTRAINT pre_pedido_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);
ALTER TABLE public.pre_pedido_itens ADD CONSTRAINT pre_pedido_itens_sabor_id_fkey FOREIGN KEY (sabor_id) REFERENCES public.produto_sabores(id);


-- public.pre_pedidos chaves estrangeiras

ALTER TABLE public.pre_pedidos ADD CONSTRAINT pre_pedidos_analisado_por_fkey FOREIGN KEY (analisado_por) REFERENCES public.users(id);
ALTER TABLE public.pre_pedidos ADD CONSTRAINT pre_pedidos_cliente_vinculado_id_fkey FOREIGN KEY (cliente_vinculado_id) REFERENCES public.clientes(id);
ALTER TABLE public.pre_pedidos ADD CONSTRAINT pre_pedidos_pedido_gerado_id_fkey FOREIGN KEY (pedido_gerado_id) REFERENCES public.pedidos(id) ON DELETE SET NULL;


-- public.produto_sabores chaves estrangeiras

ALTER TABLE public.produto_sabores ADD CONSTRAINT produto_sabores_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE CASCADE;


-- public.produtos chaves estrangeiras

ALTER TABLE public.produtos ADD CONSTRAINT produtos_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


-- public.users chaves estrangeiras

ALTER TABLE public.users ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


-- public.estatisticas_pedidos fonte

CREATE OR REPLACE VIEW public.estatisticas_pedidos
AS SELECT status,
    count(*) AS total,
    sum(total) AS valor_total
   FROM pedidos
  GROUP BY status;

-- Permissions

ALTER TABLE public.estatisticas_pedidos OWNER TO postgres;
GRANT ALL ON TABLE public.estatisticas_pedidos TO postgres;
GRANT ALL ON TABLE public.estatisticas_pedidos TO anon;
GRANT ALL ON TABLE public.estatisticas_pedidos TO authenticated;
GRANT ALL ON TABLE public.estatisticas_pedidos TO service_role;


-- public.produtos_estoque_baixo fonte

CREATE OR REPLACE VIEW public.produtos_estoque_baixo
AS SELECT id,
    codigo,
    nome,
    categoria,
    unidade,
    estoque_atual,
    estoque_minimo,
    preco,
    active,
    created_by,
    created_at,
    updated_at,
    estoque_minimo - estoque_atual AS deficit
   FROM produtos p
  WHERE active = true AND estoque_atual <= estoque_minimo
  ORDER BY (estoque_minimo - estoque_atual) DESC;

-- Permissions

ALTER TABLE public.produtos_estoque_baixo OWNER TO postgres;
GRANT ALL ON TABLE public.produtos_estoque_baixo TO postgres;
GRANT ALL ON TABLE public.produtos_estoque_baixo TO anon;
GRANT ALL ON TABLE public.produtos_estoque_baixo TO authenticated;
GRANT ALL ON TABLE public.produtos_estoque_baixo TO service_role;


-- public.v_cancelamentos_auditoria fonte

CREATE OR REPLACE VIEW public.v_cancelamentos_auditoria
AS SELECT cp.id AS cancelamento_id,
    cp.pedido_id,
    p.numero AS pedido_numero,
    p.tipo_pedido,
    cp.status_anterior,
    cp.status_novo,
    cp.motivo,
    u.full_name AS cancelado_por_usuario,
    cp.pode_reverter,
    cp.data_cancelamento,
        CASE
            WHEN cp.status_novo::text = 'CANCELADO'::text THEN '❌ Cancelado Definitivamente'::character varying
            WHEN cp.status_novo::text = 'RASCUNHO'::text THEN '🔄 Reaberto como Rascunho'::character varying
            ELSE cp.status_novo
        END AS tipo_cancelamento
   FROM cancelamento_pedidos cp
     JOIN pedidos p ON cp.pedido_id = p.id
     JOIN users u ON cp.cancelado_por = u.id
  ORDER BY cp.data_cancelamento DESC;

-- Permissions

ALTER TABLE public.v_cancelamentos_auditoria OWNER TO postgres;
GRANT ALL ON TABLE public.v_cancelamentos_auditoria TO postgres;
GRANT ALL ON TABLE public.v_cancelamentos_auditoria TO anon;
GRANT ALL ON TABLE public.v_cancelamentos_auditoria TO authenticated;
GRANT ALL ON TABLE public.v_cancelamentos_auditoria TO service_role;


-- public.vw_estoque_sabores fonte

CREATE OR REPLACE VIEW public.vw_estoque_sabores
AS SELECT p.id AS produto_id,
    p.marca,
    p.nome AS produto_nome,
    p.nome AS produto,
    p.codigo,
    ps.id AS sabor_id,
    ps.sabor,
    ps.quantidade,
    p.estoque_minimo,
    COALESCE(( SELECT em.preco_unitario
           FROM estoque_movimentacoes em
          WHERE em.produto_id = p.id AND em.sabor_id = ps.id AND em.tipo::text = 'ENTRADA'::text AND em.preco_unitario IS NOT NULL
          ORDER BY em.created_at DESC
         LIMIT 1), p.preco_compra) AS preco_compra,
    p.preco_venda,
        CASE
            WHEN ps.quantidade = 0::numeric THEN 'ZERADO'::text
            WHEN ps.quantidade <= p.estoque_minimo THEN 'BAIXO'::text
            ELSE 'OK'::text
        END AS status_estoque
   FROM produtos p
     LEFT JOIN produto_sabores ps ON p.id = ps.produto_id
  WHERE p.active = true AND ps.ativo = true
  ORDER BY p.marca, p.nome, ps.sabor;

-- Permissions

ALTER TABLE public.vw_estoque_sabores OWNER TO postgres;
GRANT ALL ON TABLE public.vw_estoque_sabores TO postgres;
GRANT ALL ON TABLE public.vw_estoque_sabores TO anon;
GRANT ALL ON TABLE public.vw_estoque_sabores TO authenticated;
GRANT ALL ON TABLE public.vw_estoque_sabores TO service_role;


-- public.vw_produtos_publicos fonte

CREATE OR REPLACE VIEW public.vw_produtos_publicos
AS SELECT id,
    codigo,
    marca,
    nome,
    unidade,
    preco_venda,
    estoque_atual,
    estoque_minimo,
        CASE
            WHEN estoque_atual = 0::numeric THEN 'ZERADO'::text
            WHEN estoque_atual <= estoque_minimo THEN 'BAIXO'::text
            ELSE 'OK'::text
        END AS status_estoque
   FROM produtos p
  WHERE active = true AND estoque_atual > 0::numeric
  ORDER BY marca, nome;

-- Permissions

ALTER TABLE public.vw_produtos_publicos OWNER TO postgres;
GRANT ALL ON TABLE public.vw_produtos_publicos TO postgres;
GRANT ALL ON TABLE public.vw_produtos_publicos TO anon;
GRANT ALL ON TABLE public.vw_produtos_publicos TO authenticated;
GRANT ALL ON TABLE public.vw_produtos_publicos TO service_role;


-- public.vw_sabores_publicos fonte

CREATE OR REPLACE VIEW public.vw_sabores_publicos
AS SELECT s.id,
    s.produto_id,
    s.sabor,
    s.quantidade,
    p.preco_venda,
    p.estoque_minimo,
    p.marca,
    p.nome AS produto_nome,
    p.codigo AS produto_codigo,
        CASE
            WHEN s.quantidade = 0::numeric THEN 'ZERADO'::text
            WHEN s.quantidade <= p.estoque_minimo THEN 'BAIXO'::text
            ELSE 'OK'::text
        END AS status_estoque
   FROM produto_sabores s
     JOIN produtos p ON p.id = s.produto_id
  WHERE s.ativo = true AND p.active = true AND s.quantidade > 0::numeric
  ORDER BY p.marca, p.nome, s.sabor;

-- Permissions

ALTER TABLE public.vw_sabores_publicos OWNER TO postgres;
GRANT ALL ON TABLE public.vw_sabores_publicos TO postgres;
GRANT ALL ON TABLE public.vw_sabores_publicos TO anon;
GRANT ALL ON TABLE public.vw_sabores_publicos TO authenticated;
GRANT ALL ON TABLE public.vw_sabores_publicos TO service_role;


-- public.vw_vendas_aguardando_despacho fonte

CREATE OR REPLACE VIEW public.vw_vendas_aguardando_despacho
AS SELECT p.id,
    p.numero,
    p.data_finalizacao,
    p.data_separacao,
    c.nome AS cliente_nome,
    c.whatsapp AS cliente_whatsapp,
    c.endereco,
    c.cidade,
    c.estado,
    u.full_name AS vendedor,
    us.full_name AS separado_por_nome,
    p.total,
    count(pi.id) AS total_itens
   FROM pedidos p
     JOIN clientes c ON p.cliente_id = c.id
     JOIN users u ON p.solicitante_id = u.id
     LEFT JOIN users us ON p.separado_por = us.id
     LEFT JOIN pedido_itens pi ON p.id = pi.pedido_id
  WHERE p.tipo_pedido::text = 'VENDA'::text AND p.status::text = 'FINALIZADO'::text AND p.status_envio::text = 'SEPARADO'::text
  GROUP BY p.id, c.nome, c.whatsapp, c.endereco, c.cidade, c.estado, u.full_name, us.full_name
  ORDER BY p.data_separacao DESC;

-- Permissions

ALTER TABLE public.vw_vendas_aguardando_despacho OWNER TO postgres;
GRANT ALL ON TABLE public.vw_vendas_aguardando_despacho TO postgres;
GRANT ALL ON TABLE public.vw_vendas_aguardando_despacho TO anon;
GRANT ALL ON TABLE public.vw_vendas_aguardando_despacho TO authenticated;
GRANT ALL ON TABLE public.vw_vendas_aguardando_despacho TO service_role;


-- public.vw_vendas_aguardando_separacao fonte

CREATE OR REPLACE VIEW public.vw_vendas_aguardando_separacao
AS SELECT p.id,
    p.numero,
    p.created_at,
    p.data_finalizacao,
    c.nome AS cliente_nome,
    c.whatsapp AS cliente_whatsapp,
    u.full_name AS vendedor,
    p.total,
    count(pi.id) AS total_itens,
    COALESCE(sum(
        CASE
            WHEN pi.conferido = true THEN 1
            ELSE 0
        END), 0::bigint) AS itens_conferidos,
        CASE
            WHEN count(pi.id) = COALESCE(sum(
            CASE
                WHEN pi.conferido = true THEN 1
                ELSE 0
            END), 0::bigint) THEN true
            ELSE false
        END AS todos_conferidos
   FROM pedidos p
     JOIN clientes c ON p.cliente_id = c.id
     JOIN users u ON p.solicitante_id = u.id
     LEFT JOIN pedido_itens pi ON p.id = pi.pedido_id
  WHERE p.tipo_pedido::text = 'VENDA'::text AND p.status::text = 'FINALIZADO'::text AND (p.status_envio IS NULL OR p.status_envio::text = 'AGUARDANDO_SEPARACAO'::text)
  GROUP BY p.id, c.nome, c.whatsapp, u.full_name
  ORDER BY p.data_finalizacao DESC;

-- Permissions

ALTER TABLE public.vw_vendas_aguardando_separacao OWNER TO postgres;
GRANT ALL ON TABLE public.vw_vendas_aguardando_separacao TO postgres;
GRANT ALL ON TABLE public.vw_vendas_aguardando_separacao TO anon;
GRANT ALL ON TABLE public.vw_vendas_aguardando_separacao TO authenticated;
GRANT ALL ON TABLE public.vw_vendas_aguardando_separacao TO service_role;


-- public.vw_vendas_resumo fonte

CREATE OR REPLACE VIEW public.vw_vendas_resumo
AS SELECT p.id,
    p.numero,
    p.created_at AS data_venda,
    c.nome AS cliente_nome,
    c.cpf_cnpj AS cliente_documento,
    u.full_name AS vendedor,
    p.total,
    p.status,
    count(pi.id) AS total_itens
   FROM pedidos p
     LEFT JOIN clientes c ON p.cliente_id = c.id
     LEFT JOIN users u ON p.solicitante_id = u.id
     LEFT JOIN pedido_itens pi ON p.id = pi.pedido_id
  WHERE p.tipo_pedido::text = 'VENDA'::text
  GROUP BY p.id, c.nome, c.cpf_cnpj, u.full_name;

-- Permissions

ALTER TABLE public.vw_vendas_resumo OWNER TO postgres;
GRANT ALL ON TABLE public.vw_vendas_resumo TO postgres;
GRANT ALL ON TABLE public.vw_vendas_resumo TO anon;
GRANT ALL ON TABLE public.vw_vendas_resumo TO authenticated;
GRANT ALL ON TABLE public.vw_vendas_resumo TO service_role;



-- DROP FUNCTION public.alterar_sabor_estoque(uuid, varchar, uuid, text, uuid);

CREATE OR REPLACE FUNCTION public.alterar_sabor_estoque(p_sabor_id uuid, p_novo_sabor character varying, p_produto_id uuid, p_observacao text DEFAULT ''::text, p_usuario_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(sucesso boolean, mensagem text, sabor_anterior character varying, sabor_novo character varying, quantidade numeric, movimentacao_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_sabor_anterior VARCHAR(100);
    v_quantidade DECIMAL(10,2);
    v_sabor_id_novo UUID;
    v_novo_sabor_id_existe UUID;
    v_movimentacao_id UUID;
    v_usuario_id_atual UUID;
BEGIN
    -- Se não foi fornecido usuário, usar o usuário autenticado
    IF p_usuario_id IS NULL THEN
        v_usuario_id_atual := auth.uid();
    ELSE
        v_usuario_id_atual := p_usuario_id;
    END IF;

    -- Validar se o sabor atual existe
    SELECT sabor, quantidade INTO v_sabor_anterior, v_quantidade
    FROM produto_sabores
    WHERE id = p_sabor_id AND produto_id = p_produto_id
    LIMIT 1;

    IF v_sabor_anterior IS NULL THEN
        RETURN QUERY SELECT false, 'Sabor não encontrado para este produto'::TEXT, NULL, NULL, NULL, NULL;
        RETURN;
    END IF;

    -- Validar se o novo sabor é diferente
    IF LOWER(TRIM(v_sabor_anterior)) = LOWER(TRIM(p_novo_sabor)) THEN
        RETURN QUERY SELECT false, 'O novo sabor deve ser diferente do sabor atual'::TEXT, v_sabor_anterior, p_novo_sabor, v_quantidade, NULL;
        RETURN;
    END IF;

    -- Verificar se já existe um sabor com esse nome para o mesmo produto
    SELECT id INTO v_novo_sabor_id_existe
    FROM produto_sabores
    WHERE produto_id = p_produto_id 
      AND LOWER(TRIM(sabor)) = LOWER(TRIM(p_novo_sabor))
    LIMIT 1;

    -- Se o novo sabor já existe, consolidar as quantidades
    IF v_novo_sabor_id_existe IS NOT NULL THEN
        -- Adicionar a quantidade ao sabor existente
        UPDATE produto_sabores
        SET quantidade = quantidade + v_quantidade,
            updated_at = NOW()
        WHERE id = v_novo_sabor_id_existe;

        -- Remover o sabor antigo
        DELETE FROM produto_sabores WHERE id = p_sabor_id;

        v_sabor_id_novo := v_novo_sabor_id_existe;
    ELSE
        -- Se não existe, apenas atualizar o nome do sabor
        UPDATE produto_sabores
        SET sabor = TRIM(p_novo_sabor),
            updated_at = NOW()
        WHERE id = p_sabor_id;

        v_sabor_id_novo := p_sabor_id;
    END IF;

    -- Registrar movimentação de correção
    INSERT INTO estoque_movimentacoes (
        produto_id,
        sabor_id,
        tipo,
        quantidade,
        estoque_anterior,
        estoque_novo,
        usuario_id,
        observacao,
        created_at,
        updated_at
    ) VALUES (
        p_produto_id,
        v_sabor_id_novo,
        'CORRECAO_SABOR',
        v_quantidade,
        v_quantidade,
        v_quantidade,
        v_usuario_id_atual,
        'Sabor alterado de "' || v_sabor_anterior || '" para "' || TRIM(p_novo_sabor) || '". ' || COALESCE(p_observacao, ''),
        NOW(),
        NOW()
    )
    RETURNING id INTO v_movimentacao_id;

    -- Retornar resultado
    RETURN QUERY SELECT 
        true,
        'Sabor alterado com sucesso!'::TEXT,
        v_sabor_anterior,
        TRIM(p_novo_sabor),
        v_quantidade,
        v_movimentacao_id;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT false, 'Erro ao alterar sabor: ' || SQLERRM, NULL, NULL, NULL, NULL;
END;
$function$
;

COMMENT ON FUNCTION public.alterar_sabor_estoque(uuid, varchar, uuid, text, uuid) IS 'Altera o sabor de um produto em estoque, consolidando quantidades se o novo sabor já existe. Registra a mudança como movimentação.';

-- Permissions

ALTER FUNCTION public.alterar_sabor_estoque(uuid, varchar, uuid, text, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.alterar_sabor_estoque(uuid, varchar, uuid, text, uuid) TO public;
GRANT ALL ON FUNCTION public.alterar_sabor_estoque(uuid, varchar, uuid, text, uuid) TO postgres;
GRANT ALL ON FUNCTION public.alterar_sabor_estoque(uuid, varchar, uuid, text, uuid) TO anon;
GRANT ALL ON FUNCTION public.alterar_sabor_estoque(uuid, varchar, uuid, text, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.alterar_sabor_estoque(uuid, varchar, uuid, text, uuid) TO service_role;

-- DROP FUNCTION public.atualizar_estoque_produto();

CREATE OR REPLACE FUNCTION public.atualizar_estoque_produto()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Atualizar estoque_atual do produto somando todos os sabores ativos
    UPDATE produtos
    SET estoque_atual = (
        SELECT COALESCE(SUM(quantidade), 0)
        FROM produto_sabores
        WHERE produto_id = COALESCE(NEW.produto_id, OLD.produto_id)
        AND ativo = true
    )
    WHERE id = COALESCE(NEW.produto_id, OLD.produto_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$function$
;

-- Permissions

ALTER FUNCTION public.atualizar_estoque_produto() OWNER TO postgres;
GRANT ALL ON FUNCTION public.atualizar_estoque_produto() TO public;
GRANT ALL ON FUNCTION public.atualizar_estoque_produto() TO postgres;
GRANT ALL ON FUNCTION public.atualizar_estoque_produto() TO anon;
GRANT ALL ON FUNCTION public.atualizar_estoque_produto() TO authenticated;
GRANT ALL ON FUNCTION public.atualizar_estoque_produto() TO service_role;

-- DROP FUNCTION public.atualizar_estoque_sabor(uuid, numeric);

CREATE OR REPLACE FUNCTION public.atualizar_estoque_sabor(p_sabor_id uuid, p_quantidade numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_estoque_atual NUMERIC;
BEGIN
    -- Buscar estoque atual
    SELECT quantidade INTO v_estoque_atual
    FROM produto_sabores
    WHERE id = p_sabor_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sabor não encontrado';
    END IF;
    
    -- Atualizar quantidade (pode ser positivo para adicionar ou negativo para remover)
    UPDATE produto_sabores
    SET quantidade = quantidade + p_quantidade
    WHERE id = p_sabor_id;
    
END;
$function$
;

-- Permissions

ALTER FUNCTION public.atualizar_estoque_sabor(uuid, numeric) OWNER TO postgres;
GRANT ALL ON FUNCTION public.atualizar_estoque_sabor(uuid, numeric) TO public;
GRANT ALL ON FUNCTION public.atualizar_estoque_sabor(uuid, numeric) TO postgres;
GRANT ALL ON FUNCTION public.atualizar_estoque_sabor(uuid, numeric) TO anon;
GRANT ALL ON FUNCTION public.atualizar_estoque_sabor(uuid, numeric) TO authenticated;
GRANT ALL ON FUNCTION public.atualizar_estoque_sabor(uuid, numeric) TO service_role;

-- DROP FUNCTION public.buscar_produto_codigo_barras(varchar);

CREATE OR REPLACE FUNCTION public.buscar_produto_codigo_barras(p_codigo character varying)
 RETURNS TABLE(id uuid, codigo character varying, codigo_barras character varying, nome character varying, unidade character varying, preco_venda numeric, estoque_atual numeric, ncm character varying, cfop character varying, cst_icms character varying, aliquota_icms numeric)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.codigo,
        p.codigo_barras,
        p.nome,
        p.unidade,
        p.preco_venda,
        p.estoque_atual,
        p.ncm,
        p.cfop,
        p.cst_icms,
        p.aliquota_icms
    FROM produtos p
    WHERE p.active = true
      AND (p.codigo_barras = p_codigo 
           OR p.codigo_barras_embalagem = p_codigo
           OR p.codigo = p_codigo)
    LIMIT 1;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.buscar_produto_codigo_barras(varchar) OWNER TO postgres;
GRANT ALL ON FUNCTION public.buscar_produto_codigo_barras(varchar) TO public;
GRANT ALL ON FUNCTION public.buscar_produto_codigo_barras(varchar) TO postgres;
GRANT ALL ON FUNCTION public.buscar_produto_codigo_barras(varchar) TO anon;
GRANT ALL ON FUNCTION public.buscar_produto_codigo_barras(varchar) TO authenticated;
GRANT ALL ON FUNCTION public.buscar_produto_codigo_barras(varchar) TO service_role;

-- DROP FUNCTION public.buscar_produto_universal(varchar);

CREATE OR REPLACE FUNCTION public.buscar_produto_universal(p_busca character varying)
 RETURNS TABLE(id uuid, codigo character varying, codigo_barras character varying, nome character varying, unidade character varying, preco_venda numeric, estoque_atual numeric, ncm character varying, cfop character varying, cst_icms character varying, aliquota_icms numeric, tipo_match character varying)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    -- Primeiro, tentar busca por código de barras exato
    RETURN QUERY
    SELECT 
        p.id,
        p.codigo,
        p.codigo_barras,
        p.nome,
        p.unidade,
        p.preco_venda,
        p.estoque_atual,
        p.ncm,
        p.cfop,
        p.cst_icms,
        p.aliquota_icms,
        'codigo'::VARCHAR as tipo_match
    FROM produtos p
    WHERE p.active = true
      AND (p.codigo_barras = p_busca 
           OR p.codigo_barras_embalagem = p_busca
           OR p.codigo = p_busca)
    LIMIT 1;
    
    -- Se não encontrou por código, buscar por nome
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            p.id,
            p.codigo,
            p.codigo_barras,
            p.nome,
            p.unidade,
            p.preco_venda,
            p.estoque_atual,
            p.ncm,
            p.cfop,
            p.cst_icms,
            p.aliquota_icms,
            'nome'::VARCHAR as tipo_match
        FROM produtos p
        WHERE p.active = true
          AND (
            p.nome ILIKE '%' || p_busca || '%'
            OR p.codigo ILIKE '%' || p_busca || '%'
          )
        ORDER BY 
            CASE 
                WHEN LOWER(p.nome) = LOWER(p_busca) THEN 1
                WHEN LOWER(p.nome) LIKE LOWER(p_busca) || '%' THEN 2
                ELSE 3
            END,
            p.nome
        LIMIT 5;
    END IF;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.buscar_produto_universal(varchar) OWNER TO postgres;
GRANT ALL ON FUNCTION public.buscar_produto_universal(varchar) TO public;
GRANT ALL ON FUNCTION public.buscar_produto_universal(varchar) TO postgres;
GRANT ALL ON FUNCTION public.buscar_produto_universal(varchar) TO anon;
GRANT ALL ON FUNCTION public.buscar_produto_universal(varchar) TO authenticated;
GRANT ALL ON FUNCTION public.buscar_produto_universal(varchar) TO service_role;

-- DROP FUNCTION public.buscar_produtos_nome(varchar);

CREATE OR REPLACE FUNCTION public.buscar_produtos_nome(p_termo character varying)
 RETURNS TABLE(id uuid, codigo character varying, codigo_barras character varying, nome character varying, unidade character varying, preco_venda numeric, estoque_atual numeric, ncm character varying, cfop character varying, cst_icms character varying, aliquota_icms numeric)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.codigo,
        p.codigo_barras,
        p.nome,
        p.unidade,
        p.preco_venda,
        p.estoque_atual,
        p.ncm,
        p.cfop,
        p.cst_icms,
        p.aliquota_icms
    FROM produtos p
    WHERE p.active = true
      AND (
        p.nome ILIKE '%' || p_termo || '%'
        OR p.codigo ILIKE '%' || p_termo || '%'
        OR p.codigo_barras ILIKE '%' || p_termo || '%'
      )
    ORDER BY 
        -- Prioridade: nome exato > nome começa com > contém no nome
        CASE 
            WHEN LOWER(p.nome) = LOWER(p_termo) THEN 1
            WHEN LOWER(p.nome) LIKE LOWER(p_termo) || '%' THEN 2
            ELSE 3
        END,
        p.nome
    LIMIT 10;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.buscar_produtos_nome(varchar) OWNER TO postgres;
GRANT ALL ON FUNCTION public.buscar_produtos_nome(varchar) TO public;
GRANT ALL ON FUNCTION public.buscar_produtos_nome(varchar) TO postgres;
GRANT ALL ON FUNCTION public.buscar_produtos_nome(varchar) TO anon;
GRANT ALL ON FUNCTION public.buscar_produtos_nome(varchar) TO authenticated;
GRANT ALL ON FUNCTION public.buscar_produtos_nome(varchar) TO service_role;

-- DROP FUNCTION public.cancelar_pedido_definitivo(uuid, uuid);

CREATE OR REPLACE FUNCTION public.cancelar_pedido_definitivo(p_pedido_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
    v_tipo_pedido VARCHAR;
    v_estoque_atual DECIMAL;
    v_estoque_novo DECIMAL;
    v_ja_cancelado BOOLEAN;
BEGIN
    -- 🔒 LOCK no pedido (PRIMEIRA COISA)
    SELECT status, tipo_pedido INTO v_status, v_tipo_pedido
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido não encontrado: %', p_pedido_id;
    END IF;
    
    -- PROTEÇÃO 1: Não cancelar já cancelados
    IF v_status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Este pedido já foi cancelado';
    END IF;
    
    -- PROTEÇÃO 2: Só cancelar FINALIZADO
    IF v_status != 'FINALIZADO' THEN
        RAISE EXCEPTION 'Apenas pedidos FINALIZADOS podem ser cancelados. Status: %', v_status;
    END IF;
    
    -- PROTEÇÃO 3: Não cancelar se já tem movimentações de cancelamento
    SELECT EXISTS(
        SELECT 1 FROM estoque_movimentacoes 
        WHERE pedido_id = p_pedido_id 
        AND observacao LIKE '%Cancelamento%'
    ) INTO v_ja_cancelado;
    
    IF v_ja_cancelado THEN
        RAISE EXCEPTION 'Este pedido já tem movimentações de cancelamento registradas';
    END IF;
    
    -- ============================================================================
    -- PARA COMPRA: Validar que há estoque disponível para remover
    -- ============================================================================
    
    IF v_tipo_pedido = 'COMPRA' THEN
        FOR v_item IN
            SELECT 
                pi.quantidade,
                p.codigo,
                ps.sabor,
                ps.quantidade as est_atual,
                ps.id as sabor_pk
            FROM pedido_itens pi
            JOIN produtos p ON p.id = pi.produto_id
            LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
            WHERE pi.pedido_id = p_pedido_id
            AND pi.sabor_id IS NOT NULL
            FOR UPDATE OF ps
        LOOP
            -- Se não tem estoque suficiente, não pode cancelar
            IF v_item.est_atual < v_item.quantidade THEN
                RAISE EXCEPTION 
                    'BLOQUEIO: Produto % (%) foi vendido! Estoque: %, tentando remover: %',
                    v_item.codigo,
                    v_item.sabor,
                    v_item.est_atual,
                    v_item.quantidade;
            END IF;
        END LOOP;
    END IF;
    
    -- ============================================================================
    -- REVERTER AS MOVIMENTAÇÕES
    -- ============================================================================
    
    FOR v_item IN
        SELECT 
            pi.produto_id,
            pi.sabor_id,
            pi.quantidade,
            pi.preco_unitario
        FROM pedido_itens pi
        WHERE pi.pedido_id = p_pedido_id
        AND pi.sabor_id IS NOT NULL
    LOOP
        DECLARE
            v_est_ant DECIMAL;
            v_est_novo DECIMAL;
        BEGIN
            -- Buscar estoque atual
            SELECT quantidade INTO v_est_ant
            FROM produto_sabores
            WHERE id = v_item.sabor_id
            FOR UPDATE;
            
            -- ============================================================================
            -- COMPRA: REMOVER quantidade (reverter a ENTRADA que foi feita)
            -- ============================================================================
            IF v_tipo_pedido = 'COMPRA' THEN
                -- Estava: quantidade = quantidade + v_item.quantidade (na finalização)
                -- Agora: quantidade = quantidade - v_item.quantidade (cancelamento)
                
                UPDATE produto_sabores
                SET quantidade = quantidade - v_item.quantidade
                WHERE id = v_item.sabor_id
                RETURNING quantidade INTO v_est_novo;
                
                -- Registrar como SAÍDA (removendo a entrada)
                INSERT INTO estoque_movimentacoes (
                    produto_id, sabor_id, tipo, quantidade,
                    estoque_anterior, estoque_novo,
                    usuario_id, pedido_id, observacao
                ) VALUES (
                    v_item.produto_id,
                    v_item.sabor_id,
                    'SAIDA',  -- Removendo, portanto SAÍDA
                    v_item.quantidade,
                    v_est_ant,
                    v_est_novo,
                    p_usuario_id,
                    p_pedido_id,
                    'Cancelamento - Reversão de entrada de compra'
                )
                ON CONFLICT DO NOTHING;
            
            -- ============================================================================
            -- VENDA: ADICIONAR quantidade de volta (reverter a SAÍDA que foi feita)
            -- ============================================================================
            ELSIF v_tipo_pedido = 'VENDA' THEN
                -- Estava: quantidade = quantidade - v_item.quantidade (na finalização)
                -- Agora: quantidade = quantidade + v_item.quantidade (devolução)
                
                UPDATE produto_sabores
                SET quantidade = quantidade + v_item.quantidade
                WHERE id = v_item.sabor_id
                RETURNING quantidade INTO v_est_novo;
                
                -- Registrar como ENTRADA (devolvendo)
                INSERT INTO estoque_movimentacoes (
                    produto_id, sabor_id, tipo, quantidade,
                    estoque_anterior, estoque_novo,
                    usuario_id, pedido_id, observacao
                ) VALUES (
                    v_item.produto_id,
                    v_item.sabor_id,
                    'ENTRADA',  -- Devolvendo, portanto ENTRADA
                    v_item.quantidade,
                    v_est_ant,
                    v_est_novo,
                    p_usuario_id,
                    p_pedido_id,
                    'Cancelamento - Devolução de venda'
                )
                ON CONFLICT DO NOTHING;
            END IF;
        END;
    END LOOP;
    
    -- ============================================================================
    -- Atualizar status do pedido
    -- ============================================================================
    UPDATE pedidos
    SET status = 'CANCELADO', aprovador_id = p_usuario_id, updated_at = NOW()
    WHERE id = p_pedido_id;
    
    RETURN TRUE;
    
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Erro ao cancelar: %', SQLERRM;
END;
$function$
;

COMMENT ON FUNCTION public.cancelar_pedido_definitivo(uuid, uuid) IS 'Cancela pedido de forma SEGURA com reversão correta de estoque:
COMPRA: quantidade = quantidade - v_item.quantidade (remove a entrada)
VENDA: quantidade = quantidade + v_item.quantidade (devolve)';

-- Permissions

ALTER FUNCTION public.cancelar_pedido_definitivo(uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.cancelar_pedido_definitivo(uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.cancelar_pedido_definitivo(uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.cancelar_pedido_definitivo(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.cancelar_pedido_definitivo(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.cancelar_pedido_definitivo(uuid, uuid) TO service_role;

-- DROP FUNCTION public.conferir_item_pedido(uuid, uuid);

CREATE OR REPLACE FUNCTION public.conferir_item_pedido(p_item_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE pedido_itens
    SET 
        conferido = true,
        conferido_por = p_usuario_id,
        data_conferencia = NOW()
    WHERE id = p_item_id;
    
    RETURN true;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.conferir_item_pedido(uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.conferir_item_pedido(uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.conferir_item_pedido(uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.conferir_item_pedido(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.conferir_item_pedido(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.conferir_item_pedido(uuid, uuid) TO service_role;

-- DROP FUNCTION public.criar_backup_movimentacoes();

CREATE OR REPLACE FUNCTION public.criar_backup_movimentacoes()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Remover backup anterior se existir
    DROP TABLE IF EXISTS estoque_movimentacoes_backup;
    
    -- Criar novo backup
    CREATE TABLE estoque_movimentacoes_backup AS 
    SELECT * FROM estoque_movimentacoes;
    
    RAISE NOTICE '✅ Backup criado com % registros', (SELECT COUNT(*) FROM estoque_movimentacoes_backup);
END;
$function$
;

-- Permissions

ALTER FUNCTION public.criar_backup_movimentacoes() OWNER TO postgres;
GRANT ALL ON FUNCTION public.criar_backup_movimentacoes() TO public;
GRANT ALL ON FUNCTION public.criar_backup_movimentacoes() TO postgres;
GRANT ALL ON FUNCTION public.criar_backup_movimentacoes() TO anon;
GRANT ALL ON FUNCTION public.criar_backup_movimentacoes() TO authenticated;
GRANT ALL ON FUNCTION public.criar_backup_movimentacoes() TO service_role;

-- DROP FUNCTION public.deletar_pedido_seguro(uuid, uuid);

CREATE OR REPLACE FUNCTION public.deletar_pedido_seguro(p_pedido_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_pedido_num VARCHAR;
    v_status VARCHAR;
BEGIN
    -- 🔒 LOCK no pedido (PRIMEIRA COISA)
    SELECT numero, status INTO v_pedido_num, v_status
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido não encontrado';
    END IF;
    
    -- Proteção: Não deletar pedidos FINALIZADOS ou CANCELADOS (apenas RASCUNHO)
    IF v_status != 'RASCUNHO' THEN
        RAISE EXCEPTION 'Apenas pedidos em RASCUNHO podem ser deletados';
    END IF;
    
    -- ============================================================================
    -- PASSO 1: Deletar estoque_movimentacoes
    -- ============================================================================
    DELETE FROM estoque_movimentacoes
    WHERE pedido_id = p_pedido_id;
    
    -- ============================================================================
    -- PASSO 2: Deletar pedido_itens
    -- ============================================================================
    DELETE FROM pedido_itens
    WHERE pedido_id = p_pedido_id;
    
    -- ============================================================================
    -- PASSO 3: Deletar cancelamento_pedidos
    -- ============================================================================
    DELETE FROM cancelamento_pedidos
    WHERE pedido_id = p_pedido_id;
    
    -- ============================================================================
    -- PASSO 4: Deletar o pedido (por último!)
    -- ============================================================================
    DELETE FROM pedidos
    WHERE id = p_pedido_id;
    
    RETURN TRUE;
    
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Erro ao deletar pedido: %', SQLERRM;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.deletar_pedido_seguro(uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.deletar_pedido_seguro(uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.deletar_pedido_seguro(uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.deletar_pedido_seguro(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.deletar_pedido_seguro(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.deletar_pedido_seguro(uuid, uuid) TO service_role;

-- DROP FUNCTION public.expirar_pre_pedidos();

CREATE OR REPLACE FUNCTION public.expirar_pre_pedidos()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    quantidade_expirados INTEGER;
BEGIN
    UPDATE pre_pedidos
    SET status = 'EXPIRADO',
        updated_at = NOW()
    WHERE status IN ('PENDENTE', 'EM_ANALISE')
      AND data_expiracao < NOW();
    
    GET DIAGNOSTICS quantidade_expirados = ROW_COUNT;
    RETURN quantidade_expirados;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.expirar_pre_pedidos() OWNER TO postgres;
GRANT ALL ON FUNCTION public.expirar_pre_pedidos() TO public;
GRANT ALL ON FUNCTION public.expirar_pre_pedidos() TO postgres;
GRANT ALL ON FUNCTION public.expirar_pre_pedidos() TO anon;
GRANT ALL ON FUNCTION public.expirar_pre_pedidos() TO authenticated;
GRANT ALL ON FUNCTION public.expirar_pre_pedidos() TO service_role;

-- DROP FUNCTION public.finalizar_pedido(uuid, uuid);

CREATE OR REPLACE FUNCTION public.finalizar_pedido(p_pedido_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
    v_tipo_pedido VARCHAR;
    v_mov_count INT;
BEGIN
    -- 🔒 Lock no pedido para evitar race condition
    SELECT status, tipo_pedido 
    INTO v_status, v_tipo_pedido
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido não encontrado: %', p_pedido_id;
    END IF;
    
    -- ✅ PROTEÇÃO 1: Não re-finalizar
    IF v_status = 'FINALIZADO' THEN
        RAISE EXCEPTION 'Este pedido já foi finalizado';
    END IF;
    
    -- ✅ PROTEÇÃO 2: Não finalizar cancelados
    IF v_status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Pedido foi cancelado e não pode ser finalizado';
    END IF;
    
    -- ✅ PROTEÇÃO 3: Verificar se movimentações já foram criadas (se sim, pedido já foi processado)
    SELECT COUNT(*) INTO v_mov_count
    FROM estoque_movimentacoes
    WHERE pedido_id = p_pedido_id;
    
    -- Se já tem movimentações de finalização, pode tentar re-executar
    -- Vai falhar no INSERT por constraint UNIQUE mas tudo bem
    
    -- ============================================================================
    -- Processar cada item do pedido
    -- ============================================================================
    
    FOR v_item IN 
        SELECT 
            pi.id as item_id,
            pi.produto_id,
            pi.sabor_id,
            pi.quantidade,
            p.codigo as produto_codigo,
            ps.sabor as sabor_nome
        FROM pedido_itens pi
        JOIN produtos p ON p.id = pi.produto_id
        LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
        WHERE pi.pedido_id = p_pedido_id
    LOOP
        DECLARE
            v_est_ant DECIMAL;
            v_est_novo DECIMAL;
            v_ajuste DECIMAL;
        BEGIN
            -- Processar sabor (com lock)
            IF v_item.sabor_id IS NOT NULL THEN
                SELECT quantidade INTO v_est_ant
                FROM produto_sabores
                WHERE id = v_item.sabor_id
                FOR UPDATE;
                
                -- Calcular ajuste
                IF v_tipo_pedido = 'COMPRA' THEN
                    v_ajuste := v_item.quantidade;
                ELSIF v_tipo_pedido = 'VENDA' THEN
                    v_ajuste := -v_item.quantidade;
                    
                    -- Validar estoque
                    IF v_est_ant < v_item.quantidade THEN
                        RAISE EXCEPTION 
                            'ESTOQUE INSUFICIENTE: % (%) - Disponível: %, Solicitado: %',
                            v_item.produto_codigo,
                            v_item.sabor_nome,
                            v_est_ant,
                            v_item.quantidade;
                    END IF;
                ELSE
                    RAISE EXCEPTION 'Tipo de pedido inválido: %', v_tipo_pedido;
                END IF;
                
                -- Atualizar estoque
                UPDATE produto_sabores
                SET quantidade = quantidade + v_ajuste
                WHERE id = v_item.sabor_id
                RETURNING quantidade INTO v_est_novo;
                
                -- ⚠️ IMPORTANTE: INSERIR, NUNCA DELETAR
                INSERT INTO estoque_movimentacoes (
                    produto_id,
                    sabor_id,
                    tipo,
                    quantidade,
                    estoque_anterior,
                    estoque_novo,
                    usuario_id,
                    pedido_id,
                    observacao
                ) VALUES (
                    v_item.produto_id,
                    v_item.sabor_id,
                    CASE WHEN v_tipo_pedido = 'COMPRA' THEN 'ENTRADA' ELSE 'SAIDA' END,
                    v_item.quantidade,
                    v_est_ant,
                    v_est_novo,
                    p_usuario_id,
                    p_pedido_id,
                    'Finalização pedido ' || v_tipo_pedido
                )
                ON CONFLICT DO NOTHING;
            ELSE
                -- Processar produto sem sabor
                SELECT estoque_atual INTO v_est_ant
                FROM produtos
                WHERE id = v_item.produto_id
                FOR UPDATE;
                
                IF v_tipo_pedido = 'COMPRA' THEN
                    v_ajuste := v_item.quantidade;
                ELSIF v_tipo_pedido = 'VENDA' THEN
                    v_ajuste := -v_item.quantidade;
                    
                    IF v_est_ant < v_item.quantidade THEN
                        RAISE EXCEPTION 
                            'ESTOQUE INSUFICIENTE: % - Disponível: %, Solicitado: %',
                            v_item.produto_codigo,
                            v_est_ant,
                            v_item.quantidade;
                    END IF;
                END IF;
                
                UPDATE produtos
                SET estoque_atual = estoque_atual + v_ajuste
                WHERE id = v_item.produto_id
                RETURNING estoque_atual INTO v_est_novo;
                
                INSERT INTO estoque_movimentacoes (
                    produto_id,
                    tipo,
                    quantidade,
                    estoque_anterior,
                    estoque_novo,
                    usuario_id,
                    pedido_id,
                    observacao
                ) VALUES (
                    v_item.produto_id,
                    CASE WHEN v_tipo_pedido = 'COMPRA' THEN 'ENTRADA' ELSE 'SAIDA' END,
                    v_item.quantidade,
                    v_est_ant,
                    v_est_novo,
                    p_usuario_id,
                    p_pedido_id,
                    'Finalização pedido ' || v_tipo_pedido
                )
                ON CONFLICT DO NOTHING;
            END IF;
        END;
    END LOOP;
    
    -- ============================================================================
    -- Atualizar status do pedido
    -- ============================================================================
    
    UPDATE pedidos 
    SET 
        status = 'FINALIZADO',
        data_finalizacao = NOW(),
        aprovador_id = p_usuario_id,
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    RETURN TRUE;
    
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Erro ao finalizar pedido: %', SQLERRM;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.finalizar_pedido(uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.finalizar_pedido(uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.finalizar_pedido(uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.finalizar_pedido(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.finalizar_pedido(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.finalizar_pedido(uuid, uuid) TO service_role;

-- DROP FUNCTION public.gerar_numero_pre_pedido();

CREATE OR REPLACE FUNCTION public.gerar_numero_pre_pedido()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    ano_atual TEXT;
    proximo_numero INTEGER;
    novo_numero TEXT;
BEGIN
    -- Obter ano atual
    ano_atual := TO_CHAR(NOW(), 'YYYY');
    
    -- Obter próximo número
    SELECT COALESCE(MAX(
        CAST(
            SUBSTRING(numero FROM 'PRE-' || ano_atual || '-(\d+)')
            AS INTEGER
        )
    ), 0) + 1
    INTO proximo_numero
    FROM pre_pedidos
    WHERE numero LIKE 'PRE-' || ano_atual || '-%';
    
    -- Gerar número formatado
    novo_numero := 'PRE-' || ano_atual || '-' || LPAD(proximo_numero::TEXT, 4, '0');
    
    NEW.numero := novo_numero;
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.gerar_numero_pre_pedido() OWNER TO postgres;
GRANT ALL ON FUNCTION public.gerar_numero_pre_pedido() TO public;
GRANT ALL ON FUNCTION public.gerar_numero_pre_pedido() TO postgres;
GRANT ALL ON FUNCTION public.gerar_numero_pre_pedido() TO anon;
GRANT ALL ON FUNCTION public.gerar_numero_pre_pedido() TO authenticated;
GRANT ALL ON FUNCTION public.gerar_numero_pre_pedido() TO service_role;

-- DROP FUNCTION public.impedir_finalizar_cancelado();

CREATE OR REPLACE FUNCTION public.impedir_finalizar_cancelado()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF OLD.status = 'CANCELADO' AND NEW.status = 'FINALIZADO' THEN
        RAISE EXCEPTION 'Não é possível finalizar um pedido cancelado! Reabra como RASCUNHO primeiro.';
    END IF;
    
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.impedir_finalizar_cancelado() OWNER TO postgres;
GRANT ALL ON FUNCTION public.impedir_finalizar_cancelado() TO public;
GRANT ALL ON FUNCTION public.impedir_finalizar_cancelado() TO postgres;
GRANT ALL ON FUNCTION public.impedir_finalizar_cancelado() TO anon;
GRANT ALL ON FUNCTION public.impedir_finalizar_cancelado() TO authenticated;
GRANT ALL ON FUNCTION public.impedir_finalizar_cancelado() TO service_role;

-- DROP FUNCTION public.marcar_pedido_despachado(uuid, uuid);

CREATE OR REPLACE FUNCTION public.marcar_pedido_despachado(p_pedido_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_status_envio VARCHAR;
BEGIN
    -- Verificar status_envio atual
    SELECT status_envio INTO v_status_envio
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF v_status_envio != 'SEPARADO' THEN
        RAISE EXCEPTION 'Apenas pedidos SEPARADOS podem ser marcados como DESPACHADO';
    END IF;
    
    -- Atualizar pedido (status_envio)
    UPDATE pedidos
    SET 
        status_envio = 'DESPACHADO',
        data_despacho = NOW(),
        despachado_por = p_usuario_id
    WHERE id = p_pedido_id;
    
    RETURN true;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.marcar_pedido_despachado(uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.marcar_pedido_despachado(uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.marcar_pedido_despachado(uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.marcar_pedido_despachado(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.marcar_pedido_despachado(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.marcar_pedido_despachado(uuid, uuid) TO service_role;

-- DROP FUNCTION public.marcar_pedido_separado(uuid, uuid);

CREATE OR REPLACE FUNCTION public.marcar_pedido_separado(p_pedido_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_status VARCHAR;
    v_todos_conferidos BOOLEAN;
BEGIN
    -- Verificar status atual
    SELECT status INTO v_status
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF v_status != 'FINALIZADO' THEN
        RAISE EXCEPTION 'Apenas pedidos FINALIZADOS podem ser marcados como SEPARADO';
    END IF;
    
    -- Verificar se todos os itens foram conferidos
    SELECT 
        COUNT(*) = COALESCE(SUM(CASE WHEN conferido = true THEN 1 ELSE 0 END), 0)
    INTO v_todos_conferidos
    FROM pedido_itens
    WHERE pedido_id = p_pedido_id;
    
    IF NOT v_todos_conferidos THEN
        RAISE EXCEPTION 'Todos os itens devem ser conferidos antes de marcar como SEPARADO';
    END IF;
    
    -- Atualizar pedido (status_envio)
    UPDATE pedidos
    SET 
        status_envio = 'SEPARADO',
        data_separacao = NOW(),
        separado_por = p_usuario_id
    WHERE id = p_pedido_id;
    
    RETURN true;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.marcar_pedido_separado(uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.marcar_pedido_separado(uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.marcar_pedido_separado(uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.marcar_pedido_separado(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.marcar_pedido_separado(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.marcar_pedido_separado(uuid, uuid) TO service_role;

-- DROP FUNCTION public.pode_cancelar_pedido(uuid);

CREATE OR REPLACE FUNCTION public.pode_cancelar_pedido(p_pedido_id uuid)
 RETURNS TABLE(pode_cancelar boolean, motivo text, conflitos text[])
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_pedido RECORD;
    v_conflitos TEXT[];
    v_mov RECORD;
    v_estoque_sabor DECIMAL(10,2);
    v_estoque_geral DECIMAL(10,2);
BEGIN
    -- Buscar pedido
    SELECT * INTO v_pedido FROM pedidos WHERE id = p_pedido_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Pedido não encontrado'::TEXT, ARRAY[]::TEXT[];
        RETURN;
    END IF;
    
    -- Verificar se já foi cancelado
    IF v_pedido.status = 'CANCELADO' THEN
        RETURN QUERY SELECT false, 'Pedido já foi cancelado'::TEXT, ARRAY['Cancelamento anterior detectado']::TEXT[];
        RETURN;
    END IF;
    
    -- Verificar se está em status cancellável
    IF v_pedido.status NOT IN ('FINALIZADO', 'APROVADO', 'ENVIADO', 'REJEITADO') THEN
        RETURN QUERY SELECT false, 
            'Pedido não está em status cancellável. Status: ' || v_pedido.status::TEXT,
            ARRAY['Status: ' || v_pedido.status]::TEXT[];
        RETURN;
    END IF;
    
    -- Se é COMPRA, validar estoque
    IF v_pedido.tipo_pedido = 'COMPRA' THEN
        v_conflitos := ARRAY[]::TEXT[];
        
        FOR v_mov IN 
            SELECT m.*, p.codigo, ps.sabor,
                   COALESCE(ps.quantidade, 0) as est_sabor,
                   p.estoque_atual as est_geral
            FROM estoque_movimentacoes m
            JOIN produtos p ON m.produto_id = p.id
            LEFT JOIN produto_sabores ps ON m.sabor_id = ps.id
            WHERE m.pedido_id = p_pedido_id AND m.tipo = 'ENTRADA'
        LOOP
            IF v_mov.sabor_id IS NOT NULL AND v_mov.est_sabor < v_mov.quantidade THEN
                v_conflitos := array_append(v_conflitos, 
                    'Produto: ' || v_mov.codigo || ' (Sabor: ' || COALESCE(v_mov.sabor, 'geral') || 
                    ') - Estoque: ' || v_mov.est_sabor || ', Tentando remover: ' || v_mov.quantidade);
            END IF;
        END LOOP;
        
        IF array_length(v_conflitos, 1) > 0 THEN
            RETURN QUERY SELECT false, 
                'Não é possível cancelar - produtos já foram vendidos',
                v_conflitos;
            RETURN;
        END IF;
    END IF;
    
    -- Se passou em todas validações
    RETURN QUERY SELECT true, 'Pedido pode ser cancelado com segurança'::TEXT, ARRAY[]::TEXT[];
END;
$function$
;

-- Permissions

ALTER FUNCTION public.pode_cancelar_pedido(uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.pode_cancelar_pedido(uuid) TO public;
GRANT ALL ON FUNCTION public.pode_cancelar_pedido(uuid) TO postgres;
GRANT ALL ON FUNCTION public.pode_cancelar_pedido(uuid) TO anon;
GRANT ALL ON FUNCTION public.pode_cancelar_pedido(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.pode_cancelar_pedido(uuid) TO service_role;

-- DROP FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text);

CREATE OR REPLACE FUNCTION public.processar_movimentacao_estoque(p_produto_id uuid, p_tipo character varying, p_quantidade numeric, p_usuario_id uuid, p_pedido_id uuid DEFAULT NULL::uuid, p_observacao text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estoque_anterior DECIMAL;
    v_estoque_novo DECIMAL;
    v_movimentacao_id UUID;
BEGIN
    -- Buscar estoque atual
    SELECT estoque_atual INTO v_estoque_anterior
    FROM produtos
    WHERE id = p_produto_id;

    -- Calcular novo estoque
    IF p_tipo = 'ENTRADA' THEN
        v_estoque_novo := v_estoque_anterior + p_quantidade;
    ELSE
        v_estoque_novo := v_estoque_anterior - p_quantidade;
    END IF;

    -- Verificar se há estoque suficiente para saída
    IF p_tipo = 'SAIDA' AND v_estoque_novo < 0 THEN
        RAISE EXCEPTION 'Estoque insuficiente para realizar a saída';
    END IF;

    -- Atualizar estoque do produto
    UPDATE produtos
    SET estoque_atual = v_estoque_novo
    WHERE id = p_produto_id;

    -- Criar registro de movimentação
    INSERT INTO estoque_movimentacoes (
        produto_id, tipo, quantidade, estoque_anterior, estoque_novo,
        pedido_id, usuario_id, observacao
    ) VALUES (
        p_produto_id, p_tipo, p_quantidade, v_estoque_anterior, v_estoque_novo,
        p_pedido_id, p_usuario_id, p_observacao
    ) RETURNING id INTO v_movimentacao_id;

    RETURN v_movimentacao_id;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text) TO public;
GRANT ALL ON FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text) TO postgres;
GRANT ALL ON FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text) TO anon;
GRANT ALL ON FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text) TO authenticated;
GRANT ALL ON FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text) TO service_role;

-- DROP FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text, uuid);

CREATE OR REPLACE FUNCTION public.processar_movimentacao_estoque(p_produto_id uuid, p_tipo character varying, p_quantidade numeric, p_usuario_id uuid, p_pedido_id uuid DEFAULT NULL::uuid, p_observacao text DEFAULT NULL::text, p_sabor_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estoque_anterior DECIMAL;
    v_estoque_novo DECIMAL;
    v_movimentacao_id UUID;
    v_sabor_qtd_anterior DECIMAL;
    v_sabor_qtd_nova DECIMAL;
BEGIN
    -- Buscar estoque atual do produto
    SELECT estoque_atual INTO v_estoque_anterior
    FROM produtos
    WHERE id = p_produto_id;

    -- Calcular novo estoque do produto (será recalculado pelo trigger)
    IF p_tipo = 'ENTRADA' THEN
        v_estoque_novo := v_estoque_anterior + p_quantidade;
    ELSE
        v_estoque_novo := v_estoque_anterior - p_quantidade;
    END IF;

    -- Se foi informado sabor_id, atualizar quantidade do sabor
    IF p_sabor_id IS NOT NULL THEN
        -- Buscar quantidade atual do sabor
        SELECT quantidade INTO v_sabor_qtd_anterior
        FROM produto_sabores
        WHERE id = p_sabor_id;

        -- Calcular nova quantidade do sabor
        IF p_tipo = 'ENTRADA' THEN
            v_sabor_qtd_nova := v_sabor_qtd_anterior + p_quantidade;
        ELSE
            v_sabor_qtd_nova := v_sabor_qtd_anterior - p_quantidade;
        END IF;

        -- Verificar se há estoque suficiente do sabor para saída
        IF p_tipo = 'SAIDA' AND v_sabor_qtd_nova < 0 THEN
            RAISE EXCEPTION 'Estoque insuficiente do sabor para realizar a saída';
        END IF;

        -- Atualizar quantidade do sabor
        UPDATE produto_sabores
        SET quantidade = v_sabor_qtd_nova
        WHERE id = p_sabor_id;

        -- O trigger atualizar_estoque_produto() irá somar todos os sabores
        -- e atualizar automaticamente o estoque_atual do produto
        
    ELSE
        -- Sem sabor informado: verificar estoque total do produto
        IF p_tipo = 'SAIDA' AND v_estoque_novo < 0 THEN
            RAISE EXCEPTION 'Estoque insuficiente para realizar a saída';
        END IF;

        -- Atualizar estoque do produto manualmente (quando não há sabor)
        UPDATE produtos
        SET estoque_atual = v_estoque_novo
        WHERE id = p_produto_id;
    END IF;

    -- Criar registro de movimentação com sabor_id
    INSERT INTO estoque_movimentacoes (
        produto_id, tipo, quantidade, estoque_anterior, estoque_novo,
        pedido_id, usuario_id, observacao, sabor_id
    ) VALUES (
        p_produto_id, p_tipo, p_quantidade, v_estoque_anterior, v_estoque_novo,
        p_pedido_id, p_usuario_id, p_observacao, p_sabor_id
    ) RETURNING id INTO v_movimentacao_id;

    RETURN v_movimentacao_id;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text, uuid) TO public;
GRANT ALL ON FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text, uuid) TO postgres;
GRANT ALL ON FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text, uuid) TO anon;
GRANT ALL ON FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.processar_movimentacao_estoque(uuid, varchar, numeric, uuid, uuid, text, uuid) TO service_role;

-- DROP FUNCTION public.reabrir_pedido_para_rascunho(uuid, uuid);

CREATE OR REPLACE FUNCTION public.reabrir_pedido_para_rascunho(p_pedido_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
    v_tipo_pedido VARCHAR;
    v_est_ant DECIMAL;
    v_est_novo DECIMAL;
BEGIN
    -- 🔒 LOCK no pedido
    SELECT status, tipo_pedido INTO v_status, v_tipo_pedido
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido não encontrado: %', p_pedido_id;
    END IF;
    
    -- Proteção: Só reabrir se estiver FINALIZADO
    IF v_status != 'FINALIZADO' THEN
        RAISE EXCEPTION 'Apenas pedidos FINALIZADOS podem ser reabertos. Status atual: %', v_status;
    END IF;
    
    -- ============================================================================
    -- PASSO 1: REVERTER o estoque
    -- ============================================================================
    
    FOR v_item IN
        SELECT 
            pi.produto_id,
            pi.sabor_id,
            pi.quantidade,
            pi.preco_unitario
        FROM pedido_itens pi
        WHERE pi.pedido_id = p_pedido_id
        AND pi.sabor_id IS NOT NULL
    LOOP
        -- Buscar estoque atual
        SELECT quantidade INTO v_est_ant
        FROM produto_sabores
        WHERE id = v_item.sabor_id
        FOR UPDATE;
        
        -- ============================================================================
        -- COMPRA: REMOVER quantidade (reverter a ENTRADA que foi adicionada)
        -- ============================================================================
        IF v_tipo_pedido = 'COMPRA' THEN
            UPDATE produto_sabores
            SET quantidade = quantidade - v_item.quantidade
            WHERE id = v_item.sabor_id
            RETURNING quantidade INTO v_est_novo;
            
            INSERT INTO estoque_movimentacoes (
                produto_id, sabor_id, tipo, quantidade,
                estoque_anterior, estoque_novo,
                usuario_id, pedido_id, observacao
            ) VALUES (
                v_item.produto_id,
                v_item.sabor_id,
                'SAIDA',
                v_item.quantidade,
                v_est_ant,
                v_est_novo,
                p_usuario_id,
                p_pedido_id,
                'Reabertura - Reversão de entrada de compra'
            )
            ON CONFLICT DO NOTHING;
        
        -- ============================================================================
        -- VENDA: ADICIONAR quantidade de volta (reverter a SAÍDA que foi feita)
        -- ============================================================================
        ELSIF v_tipo_pedido = 'VENDA' THEN
            UPDATE produto_sabores
            SET quantidade = quantidade + v_item.quantidade
            WHERE id = v_item.sabor_id
            RETURNING quantidade INTO v_est_novo;
            
            INSERT INTO estoque_movimentacoes (
                produto_id, sabor_id, tipo, quantidade,
                estoque_anterior, estoque_novo,
                usuario_id, pedido_id, observacao
            ) VALUES (
                v_item.produto_id,
                v_item.sabor_id,
                'ENTRADA',
                v_item.quantidade,
                v_est_ant,
                v_est_novo,
                p_usuario_id,
                p_pedido_id,
                'Reabertura - Devolução de venda'
            )
            ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;
    
    -- ============================================================================
    -- PASSO 2: Mudar status para RASCUNHO (para editar)
    -- ============================================================================
    
    UPDATE pedidos
    SET 
        status = 'RASCUNHO',
        data_finalizacao = NULL,
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    RETURN TRUE;
    
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Erro ao reabrir pedido: %', SQLERRM;
END;
$function$
;

COMMENT ON FUNCTION public.reabrir_pedido_para_rascunho(uuid, uuid) IS 'Reabre pedido finalizado como RASCUNHO para edição.
REVERTE O ESTOQUE (remove as movimentações da finalização anterior).
Quando refinalizar, o estoque será adicionado de novo.';

-- Permissions

ALTER FUNCTION public.reabrir_pedido_para_rascunho(uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.reabrir_pedido_para_rascunho(uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.reabrir_pedido_para_rascunho(uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.reabrir_pedido_para_rascunho(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.reabrir_pedido_para_rascunho(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.reabrir_pedido_para_rascunho(uuid, uuid) TO service_role;

-- DROP FUNCTION public.reprocessar_estoque_completo();

CREATE OR REPLACE FUNCTION public.reprocessar_estoque_completo()
 RETURNS TABLE(pedidos_processados integer, movimentacoes_criadas integer, mensagem text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_pedido RECORD;
    v_item RECORD;
    v_estoque_anterior DECIMAL;
    v_estoque_novo DECIMAL;
    v_total_processados INTEGER := 0;
    v_total_movs INTEGER := 0;
BEGIN
    RAISE NOTICE '🔧 REPROCESSANDO PEDIDOS FINALIZADOS...';
    RAISE NOTICE '════════════════════════════════════════';
    
    -- PASSO 1: Limpar todas as movimentações
    DELETE FROM estoque_movimentacoes WHERE true;
    RAISE NOTICE '✓ Movimentações limpas';
    
    -- PASSO 2: Zerar estoque de todos os produtos
    UPDATE produto_sabores SET quantidade = 0 WHERE true;
    RAISE NOTICE '✓ Estoque zerado';
    
    -- PASSO 3: Processar cada pedido finalizado na ordem cronológica
    FOR v_pedido IN 
        SELECT p.*
        FROM pedidos p
        WHERE p.status = 'FINALIZADO'
        ORDER BY p.data_finalizacao NULLS LAST, p.created_at
    LOOP
        RAISE NOTICE '📦 Processando pedido: % (%)', v_pedido.numero, v_pedido.tipo_pedido;
        
        -- Processar cada item do pedido
        FOR v_item IN
            SELECT 
                pi.*,
                ps.quantidade as estoque_atual
            FROM pedido_itens pi
            LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
            WHERE pi.pedido_id = v_pedido.id
        LOOP
            IF v_item.sabor_id IS NOT NULL THEN
                v_estoque_anterior := COALESCE(v_item.estoque_atual, 0);
                
                IF v_pedido.tipo_pedido = 'COMPRA' THEN
                    -- COMPRA: ADICIONAR ao estoque
                    UPDATE produto_sabores
                    SET quantidade = quantidade + v_item.quantidade
                    WHERE id = v_item.sabor_id
                    RETURNING quantidade INTO v_estoque_novo;
                    
                    -- Registrar movimentação de ENTRADA
                    INSERT INTO estoque_movimentacoes (
                        produto_id, sabor_id, tipo, quantidade,
                        estoque_anterior, estoque_novo,
                        usuario_id, pedido_id, observacao,
                        created_at
                    ) VALUES (
                        v_item.produto_id,
                        v_item.sabor_id,
                        'ENTRADA',
                        v_item.quantidade,
                        v_estoque_anterior,
                        v_estoque_novo,
                        v_pedido.solicitante_id,
                        v_pedido.id,
                        'Entrada - Finalização pedido compra',
                        COALESCE(v_pedido.data_finalizacao, v_pedido.created_at)
                    );
                    
                    RAISE NOTICE '  ⬆️  +%: % → %', v_item.quantidade, v_estoque_anterior, v_estoque_novo;
                    
                ELSIF v_pedido.tipo_pedido = 'VENDA' THEN
                    -- VENDA: REMOVER do estoque
                    UPDATE produto_sabores
                    SET quantidade = quantidade - v_item.quantidade
                    WHERE id = v_item.sabor_id
                    RETURNING quantidade INTO v_estoque_novo;
                    
                    -- Registrar movimentação de SAÍDA
                    INSERT INTO estoque_movimentacoes (
                        produto_id, sabor_id, tipo, quantidade,
                        estoque_anterior, estoque_novo,
                        usuario_id, pedido_id, observacao,
                        created_at
                    ) VALUES (
                        v_item.produto_id,
                        v_item.sabor_id,
                        'SAIDA',
                        v_item.quantidade,
                        v_estoque_anterior,
                        v_estoque_novo,
                        v_pedido.solicitante_id,
                        v_pedido.id,
                        'Saída - Finalização pedido venda',
                        COALESCE(v_pedido.data_finalizacao, v_pedido.created_at)
                    );
                    
                    RAISE NOTICE '  ⬇️  -%: % → %', v_item.quantidade, v_estoque_anterior, v_estoque_novo;
                END IF;
                
                v_total_movs := v_total_movs + 1;
            END IF;
        END LOOP;
        
        v_total_processados := v_total_processados + 1;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════';
    RAISE NOTICE '✅ REPROCESSAMENTO CONCLUÍDO!';
    RAISE NOTICE '   Pedidos processados: %', v_total_processados;
    RAISE NOTICE '   Movimentações criadas: %', v_total_movs;
    RAISE NOTICE '════════════════════════════════════════';
    
    RETURN QUERY SELECT 
        v_total_processados,
        v_total_movs,
        'Reprocessamento concluído com sucesso!'::TEXT;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.reprocessar_estoque_completo() OWNER TO postgres;
GRANT ALL ON FUNCTION public.reprocessar_estoque_completo() TO public;
GRANT ALL ON FUNCTION public.reprocessar_estoque_completo() TO postgres;
GRANT ALL ON FUNCTION public.reprocessar_estoque_completo() TO anon;
GRANT ALL ON FUNCTION public.reprocessar_estoque_completo() TO authenticated;
GRANT ALL ON FUNCTION public.reprocessar_estoque_completo() TO service_role;

-- DROP FUNCTION public.update_empresa_updated_at();

CREATE OR REPLACE FUNCTION public.update_empresa_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.update_empresa_updated_at() OWNER TO postgres;
GRANT ALL ON FUNCTION public.update_empresa_updated_at() TO public;
GRANT ALL ON FUNCTION public.update_empresa_updated_at() TO postgres;
GRANT ALL ON FUNCTION public.update_empresa_updated_at() TO anon;
GRANT ALL ON FUNCTION public.update_empresa_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.update_empresa_updated_at() TO service_role;

-- DROP FUNCTION public.update_pedido_total();

CREATE OR REPLACE FUNCTION public.update_pedido_total()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE pedidos 
    SET total = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM pedido_itens
        WHERE pedido_id = NEW.pedido_id
    )
    WHERE id = NEW.pedido_id;
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.update_pedido_total() OWNER TO postgres;
GRANT ALL ON FUNCTION public.update_pedido_total() TO public;
GRANT ALL ON FUNCTION public.update_pedido_total() TO postgres;
GRANT ALL ON FUNCTION public.update_pedido_total() TO anon;
GRANT ALL ON FUNCTION public.update_pedido_total() TO authenticated;
GRANT ALL ON FUNCTION public.update_pedido_total() TO service_role;

-- DROP FUNCTION public.update_pre_pedidos_updated_at();

CREATE OR REPLACE FUNCTION public.update_pre_pedidos_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.update_pre_pedidos_updated_at() OWNER TO postgres;
GRANT ALL ON FUNCTION public.update_pre_pedidos_updated_at() TO public;
GRANT ALL ON FUNCTION public.update_pre_pedidos_updated_at() TO postgres;
GRANT ALL ON FUNCTION public.update_pre_pedidos_updated_at() TO anon;
GRANT ALL ON FUNCTION public.update_pre_pedidos_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.update_pre_pedidos_updated_at() TO service_role;

-- DROP FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO public;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO postgres;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO anon;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO authenticated;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO service_role;

-- DROP FUNCTION public.validar_estoque_nao_negativo();

CREATE OR REPLACE FUNCTION public.validar_estoque_nao_negativo()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.estoque_atual < 0 THEN
        RAISE EXCEPTION 'BLOQUEIO: Estoque não pode ser negativo! Produto: %, Estoque resultante: %',
            NEW.codigo, NEW.estoque_atual;
    END IF;
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.validar_estoque_nao_negativo() OWNER TO postgres;
GRANT ALL ON FUNCTION public.validar_estoque_nao_negativo() TO public;
GRANT ALL ON FUNCTION public.validar_estoque_nao_negativo() TO postgres;
GRANT ALL ON FUNCTION public.validar_estoque_nao_negativo() TO anon;
GRANT ALL ON FUNCTION public.validar_estoque_nao_negativo() TO authenticated;
GRANT ALL ON FUNCTION public.validar_estoque_nao_negativo() TO service_role;

-- DROP FUNCTION public.validar_estoque_sabor_nao_negativo();

CREATE OR REPLACE FUNCTION public.validar_estoque_sabor_nao_negativo()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.quantidade < 0 THEN
        RAISE EXCEPTION 'BLOQUEIO: Estoque de sabor não pode ser negativo! Sabor: %, Estoque resultante: %',
            NEW.sabor, NEW.quantidade;
    END IF;
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.validar_estoque_sabor_nao_negativo() OWNER TO postgres;
GRANT ALL ON FUNCTION public.validar_estoque_sabor_nao_negativo() TO public;
GRANT ALL ON FUNCTION public.validar_estoque_sabor_nao_negativo() TO postgres;
GRANT ALL ON FUNCTION public.validar_estoque_sabor_nao_negativo() TO anon;
GRANT ALL ON FUNCTION public.validar_estoque_sabor_nao_negativo() TO authenticated;
GRANT ALL ON FUNCTION public.validar_estoque_sabor_nao_negativo() TO service_role;

-- DROP FUNCTION public.verificar_consistencia_estoque();

CREATE OR REPLACE FUNCTION public.verificar_consistencia_estoque()
 RETURNS TABLE(produto text, sabor text, estoque_final numeric, total_entradas numeric, total_saidas numeric, estoque_calculado numeric, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        p.nome::TEXT as produto,
        ps.sabor::TEXT as sabor,
        ps.quantidade::DECIMAL as estoque_final,
        COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'ENTRADA'), 0)::DECIMAL as total_entradas,
        COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'SAIDA'), 0)::DECIMAL as total_saidas,
        (COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'ENTRADA'), 0) -
         COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'SAIDA'), 0))::DECIMAL as estoque_calculado,
        CASE 
            WHEN ps.quantidade = 
                 (COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'ENTRADA'), 0) -
                  COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'SAIDA'), 0))
            THEN '✅ OK'::TEXT
            ELSE '⚠️ Inconsistente'::TEXT
        END as status
    FROM produtos p
    JOIN produto_sabores ps ON ps.produto_id = p.id
    WHERE p.active = true
    ORDER BY p.nome, ps.sabor;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.verificar_consistencia_estoque() OWNER TO postgres;
GRANT ALL ON FUNCTION public.verificar_consistencia_estoque() TO public;
GRANT ALL ON FUNCTION public.verificar_consistencia_estoque() TO postgres;
GRANT ALL ON FUNCTION public.verificar_consistencia_estoque() TO anon;
GRANT ALL ON FUNCTION public.verificar_consistencia_estoque() TO authenticated;
GRANT ALL ON FUNCTION public.verificar_consistencia_estoque() TO service_role;

-- DROP FUNCTION public.verificar_movimentacao_existente(uuid, uuid, uuid);

CREATE OR REPLACE FUNCTION public.verificar_movimentacao_existente(p_pedido_id uuid, p_produto_id uuid, p_sabor_id uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_existe BOOLEAN;
BEGIN
    -- Verificar se existe movimentação EXATA (mesmo produto + mesmo sabor + mesmo pedido)
    IF p_sabor_id IS NOT NULL THEN
        -- Para pedidos com sabores específicos
        SELECT EXISTS(
            SELECT 1
            FROM estoque_movimentacoes
            WHERE pedido_id = p_pedido_id
            AND produto_id = p_produto_id
            AND sabor_id = p_sabor_id
        ) INTO v_existe;
    ELSE
        -- Para pedidos sem sabores (produtos simples)
        SELECT EXISTS(
            SELECT 1
            FROM estoque_movimentacoes
            WHERE pedido_id = p_pedido_id
            AND produto_id = p_produto_id
            AND sabor_id IS NULL
        ) INTO v_existe;
    END IF;
    
    RETURN v_existe;
END;
$function$
;

COMMENT ON FUNCTION public.verificar_movimentacao_existente(uuid, uuid, uuid) IS 'Verifica se já existe uma movimentação para o pedido+produto+sabor especificado. 
Útil para validações adicionais antes de criar movimentações.';

-- Permissions

ALTER FUNCTION public.verificar_movimentacao_existente(uuid, uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.verificar_movimentacao_existente(uuid, uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.verificar_movimentacao_existente(uuid, uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.verificar_movimentacao_existente(uuid, uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.verificar_movimentacao_existente(uuid, uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.verificar_movimentacao_existente(uuid, uuid, uuid) TO service_role;

-- DROP FUNCTION public.voltar_para_despacho(uuid, uuid);

CREATE OR REPLACE FUNCTION public.voltar_para_despacho(p_pedido_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_status_envio VARCHAR;
BEGIN
    -- Verificar status_envio atual
    SELECT status_envio INTO v_status_envio
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF v_status_envio != 'DESPACHADO' THEN
        RAISE EXCEPTION 'Apenas pedidos DESPACHADOS podem voltar para despacho';
    END IF;
    
    -- Voltar para SEPARADO
    UPDATE pedidos
    SET 
        status_envio = 'SEPARADO',
        data_despacho = NULL,
        despachado_por = NULL
    WHERE id = p_pedido_id;
    
    RETURN true;
END;
$function$
;

COMMENT ON FUNCTION public.voltar_para_despacho(uuid, uuid) IS 'Reverte pedido DESPACHADO para SEPARADO';

-- Permissions

ALTER FUNCTION public.voltar_para_despacho(uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.voltar_para_despacho(uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.voltar_para_despacho(uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.voltar_para_despacho(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.voltar_para_despacho(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.voltar_para_despacho(uuid, uuid) TO service_role;

-- DROP FUNCTION public.voltar_para_separacao(uuid, uuid);

CREATE OR REPLACE FUNCTION public.voltar_para_separacao(p_pedido_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_status_envio VARCHAR;
BEGIN
    -- Verificar status_envio atual
    SELECT status_envio INTO v_status_envio
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF v_status_envio != 'SEPARADO' THEN
        RAISE EXCEPTION 'Apenas pedidos SEPARADOS podem voltar para separação';
    END IF;
    
    -- Voltar para NULL (aguardando separação)
    UPDATE pedidos
    SET 
        status_envio = NULL,
        data_separacao = NULL,
        separado_por = NULL
    WHERE id = p_pedido_id;
    
    -- Desmarcar todos os itens
    UPDATE pedido_itens
    SET 
        conferido = false,
        conferido_por = NULL,
        data_conferencia = NULL
    WHERE pedido_id = p_pedido_id;
    
    RETURN true;
END;
$function$
;

COMMENT ON FUNCTION public.voltar_para_separacao(uuid, uuid) IS 'Reverte pedido SEPARADO para AGUARDANDO_SEPARACAO e desmarca itens';

-- Permissions

ALTER FUNCTION public.voltar_para_separacao(uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.voltar_para_separacao(uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.voltar_para_separacao(uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.voltar_para_separacao(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.voltar_para_separacao(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.voltar_para_separacao(uuid, uuid) TO service_role;


-- Permissions

GRANT ALL ON SCHEMA public TO pg_database_owner;
GRANT USAGE ON SCHEMA public TO public;
GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;

-- DROP SCHEMA auth;

CREATE SCHEMA auth AUTHORIZATION supabase_admin;

-- DROP TYPE auth."aal_level";

CREATE TYPE auth."aal_level" AS ENUM (
	'aal1',
	'aal2',
	'aal3');

-- DROP TYPE auth."code_challenge_method";

CREATE TYPE auth."code_challenge_method" AS ENUM (
	's256',
	'plain');

-- DROP TYPE auth."factor_status";

CREATE TYPE auth."factor_status" AS ENUM (
	'unverified',
	'verified');

-- DROP TYPE auth."factor_type";

CREATE TYPE auth."factor_type" AS ENUM (
	'totp',
	'webauthn',
	'phone');

-- DROP TYPE auth."oauth_authorization_status";

CREATE TYPE auth."oauth_authorization_status" AS ENUM (
	'pending',
	'approved',
	'denied',
	'expired');

-- DROP TYPE auth."oauth_client_type";

CREATE TYPE auth."oauth_client_type" AS ENUM (
	'public',
	'confidential');

-- DROP TYPE auth."oauth_registration_type";

CREATE TYPE auth."oauth_registration_type" AS ENUM (
	'dynamic',
	'manual');

-- DROP TYPE auth."oauth_response_type";

CREATE TYPE auth."oauth_response_type" AS ENUM (
	'code');

-- DROP TYPE auth."one_time_token_type";

CREATE TYPE auth."one_time_token_type" AS ENUM (
	'confirmation_token',
	'reauthentication_token',
	'recovery_token',
	'email_change_token_new',
	'email_change_token_current',
	'phone_change_token');

-- DROP SEQUENCE auth.refresh_tokens_id_seq;

CREATE SEQUENCE auth.refresh_tokens_id_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 9223372036854775807
	START 1
	CACHE 1
	NO CYCLE;

-- Permissions

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNER TO supabase_auth_admin;
GRANT ALL ON SEQUENCE auth.refresh_tokens_id_seq TO supabase_auth_admin;
GRANT ALL ON SEQUENCE auth.refresh_tokens_id_seq TO dashboard_user;
GRANT ALL ON SEQUENCE auth.refresh_tokens_id_seq TO postgres;
-- auth.audit_log_entries definição

-- Drop table

-- DROP TABLE auth.audit_log_entries;

CREATE TABLE auth.audit_log_entries ( instance_id uuid NULL, id uuid NOT NULL, payload json NULL, created_at timestamptz NULL, ip_address varchar(64) DEFAULT ''::character varying NOT NULL, CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id));
CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);
COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';

-- Permissions

ALTER TABLE auth.audit_log_entries OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.audit_log_entries TO supabase_auth_admin;
GRANT ALL ON TABLE auth.audit_log_entries TO dashboard_user;
GRANT ALL ON TABLE auth.audit_log_entries TO postgres;


-- auth.flow_state definição

-- Drop table

-- DROP TABLE auth.flow_state;

CREATE TABLE auth.flow_state ( id uuid NOT NULL, user_id uuid NULL, auth_code text NULL, "code_challenge_method" auth."code_challenge_method" NULL, code_challenge text NULL, provider_type text NOT NULL, provider_access_token text NULL, provider_refresh_token text NULL, created_at timestamptz NULL, updated_at timestamptz NULL, authentication_method text NOT NULL, auth_code_issued_at timestamptz NULL, invite_token text NULL, referrer text NULL, oauth_client_state_id uuid NULL, linking_target_id uuid NULL, email_optional bool DEFAULT false NOT NULL, CONSTRAINT flow_state_pkey PRIMARY KEY (id));
CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);
CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);
CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);
COMMENT ON TABLE auth.flow_state IS 'Stores metadata for all OAuth/SSO login flows';

-- Permissions

ALTER TABLE auth.flow_state OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.flow_state TO postgres;
GRANT ALL ON TABLE auth.flow_state TO supabase_auth_admin;
GRANT ALL ON TABLE auth.flow_state TO dashboard_user;


-- auth.instances definição

-- Drop table

-- DROP TABLE auth.instances;

CREATE TABLE auth.instances ( id uuid NOT NULL, "uuid" uuid NULL, raw_base_config text NULL, created_at timestamptz NULL, updated_at timestamptz NULL, CONSTRAINT instances_pkey PRIMARY KEY (id));
COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';

-- Permissions

ALTER TABLE auth.instances OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.instances TO supabase_auth_admin;
GRANT ALL ON TABLE auth.instances TO dashboard_user;
GRANT ALL ON TABLE auth.instances TO postgres;


-- auth.oauth_client_states definição

-- Drop table

-- DROP TABLE auth.oauth_client_states;

CREATE TABLE auth.oauth_client_states ( id uuid NOT NULL, provider_type text NOT NULL, code_verifier text NULL, created_at timestamptz NOT NULL, CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id));
CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);
COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';

-- Permissions

ALTER TABLE auth.oauth_client_states OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.oauth_client_states TO postgres;
GRANT ALL ON TABLE auth.oauth_client_states TO supabase_auth_admin;
GRANT ALL ON TABLE auth.oauth_client_states TO dashboard_user;


-- auth.oauth_clients definição

-- Drop table

-- DROP TABLE auth.oauth_clients;

CREATE TABLE auth.oauth_clients ( id uuid NOT NULL, client_secret_hash text NULL, registration_type auth."oauth_registration_type" NOT NULL, redirect_uris text NOT NULL, grant_types text NOT NULL, client_name text NULL, client_uri text NULL, logo_uri text NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, deleted_at timestamptz NULL, client_type auth."oauth_client_type" DEFAULT 'confidential'::auth.oauth_client_type NOT NULL, token_endpoint_auth_method text NOT NULL, CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)), CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)), CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048)), CONSTRAINT oauth_clients_pkey PRIMARY KEY (id), CONSTRAINT oauth_clients_token_endpoint_auth_method_check CHECK ((token_endpoint_auth_method = ANY (ARRAY['client_secret_basic'::text, 'client_secret_post'::text, 'none'::text]))));
CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);

-- Permissions

ALTER TABLE auth.oauth_clients OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.oauth_clients TO postgres;
GRANT ALL ON TABLE auth.oauth_clients TO supabase_auth_admin;
GRANT ALL ON TABLE auth.oauth_clients TO dashboard_user;


-- auth.schema_migrations definição

-- Drop table

-- DROP TABLE auth.schema_migrations;

CREATE TABLE auth.schema_migrations ( "version" varchar(255) NOT NULL, CONSTRAINT schema_migrations_pkey PRIMARY KEY (version));
COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';

-- Permissions

ALTER TABLE auth.schema_migrations OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.schema_migrations TO supabase_auth_admin;
GRANT SELECT ON TABLE auth.schema_migrations TO postgres WITH GRANT OPTION;


-- auth.sso_providers definição

-- Drop table

-- DROP TABLE auth.sso_providers;

CREATE TABLE auth.sso_providers ( id uuid NOT NULL, resource_id text NULL, created_at timestamptz NULL, updated_at timestamptz NULL, disabled bool NULL, CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0))), CONSTRAINT sso_providers_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));
CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);
COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';

-- Column comments

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';

-- Permissions

ALTER TABLE auth.sso_providers OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.sso_providers TO postgres;
GRANT ALL ON TABLE auth.sso_providers TO supabase_auth_admin;
GRANT ALL ON TABLE auth.sso_providers TO dashboard_user;


-- auth.users definição

-- Drop table

-- DROP TABLE auth.users;

CREATE TABLE auth.users ( instance_id uuid NULL, id uuid NOT NULL, aud varchar(255) NULL, "role" varchar(255) NULL, email varchar(255) NULL, encrypted_password varchar(255) NULL, email_confirmed_at timestamptz NULL, invited_at timestamptz NULL, confirmation_token varchar(255) NULL, confirmation_sent_at timestamptz NULL, recovery_token varchar(255) NULL, recovery_sent_at timestamptz NULL, email_change_token_new varchar(255) NULL, email_change varchar(255) NULL, email_change_sent_at timestamptz NULL, last_sign_in_at timestamptz NULL, raw_app_meta_data jsonb NULL, raw_user_meta_data jsonb NULL, is_super_admin bool NULL, created_at timestamptz NULL, updated_at timestamptz NULL, phone text DEFAULT NULL::character varying NULL, phone_confirmed_at timestamptz NULL, phone_change text DEFAULT ''::character varying NULL, phone_change_token varchar(255) DEFAULT ''::character varying NULL, phone_change_sent_at timestamptz NULL, confirmed_at timestamptz GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED NULL, email_change_token_current varchar(255) DEFAULT ''::character varying NULL, email_change_confirm_status int2 DEFAULT 0 NULL, banned_until timestamptz NULL, reauthentication_token varchar(255) DEFAULT ''::character varying NULL, reauthentication_sent_at timestamptz NULL, is_sso_user bool DEFAULT false NOT NULL, deleted_at timestamptz NULL, is_anonymous bool DEFAULT false NOT NULL, CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2))), CONSTRAINT users_phone_key UNIQUE (phone), CONSTRAINT users_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);
CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);
CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);
CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);
CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);
CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);
COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';
CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));
CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);
CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);
COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';

-- Column comments

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';

-- Permissions

ALTER TABLE auth.users OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.users TO supabase_auth_admin;
GRANT ALL ON TABLE auth.users TO dashboard_user;
GRANT ALL ON TABLE auth.users TO postgres;


-- auth.identities definição

-- Drop table

-- DROP TABLE auth.identities;

CREATE TABLE auth.identities ( provider_id text NOT NULL, user_id uuid NOT NULL, identity_data jsonb NOT NULL, provider text NOT NULL, last_sign_in_at timestamptz NULL, created_at timestamptz NULL, updated_at timestamptz NULL, email text GENERATED ALWAYS AS (lower(identity_data ->> 'email'::text)) STORED NULL, id uuid DEFAULT gen_random_uuid() NOT NULL, CONSTRAINT identities_pkey PRIMARY KEY (id), CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider), CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);
COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';
CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);
COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';

-- Column comments

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';

-- Permissions

ALTER TABLE auth.identities OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.identities TO postgres;
GRANT ALL ON TABLE auth.identities TO supabase_auth_admin;
GRANT ALL ON TABLE auth.identities TO dashboard_user;


-- auth.mfa_factors definição

-- Drop table

-- DROP TABLE auth.mfa_factors;

CREATE TABLE auth.mfa_factors ( id uuid NOT NULL, user_id uuid NOT NULL, friendly_name text NULL, "factor_type" auth."factor_type" NOT NULL, status auth."factor_status" NOT NULL, created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL, secret text NULL, phone text NULL, last_challenged_at timestamptz NULL, web_authn_credential jsonb NULL, web_authn_aaguid uuid NULL, last_webauthn_challenge_data jsonb NULL, CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at), CONSTRAINT mfa_factors_pkey PRIMARY KEY (id), CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);
CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);
CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);
CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);
COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';

-- Column comments

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';

-- Permissions

ALTER TABLE auth.mfa_factors OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.mfa_factors TO postgres;
GRANT ALL ON TABLE auth.mfa_factors TO supabase_auth_admin;
GRANT ALL ON TABLE auth.mfa_factors TO dashboard_user;


-- auth.oauth_authorizations definição

-- Drop table

-- DROP TABLE auth.oauth_authorizations;

CREATE TABLE auth.oauth_authorizations ( id uuid NOT NULL, authorization_id text NOT NULL, client_id uuid NOT NULL, user_id uuid NULL, redirect_uri text NOT NULL, "scope" text NOT NULL, state text NULL, resource text NULL, code_challenge text NULL, "code_challenge_method" auth."code_challenge_method" NULL, response_type auth."oauth_response_type" DEFAULT 'code'::auth.oauth_response_type NOT NULL, status auth."oauth_authorization_status" DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL, authorization_code text NULL, created_at timestamptz DEFAULT now() NOT NULL, expires_at timestamptz DEFAULT now() + '00:03:00'::interval NOT NULL, approved_at timestamptz NULL, nonce text NULL, CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code), CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)), CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id), CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)), CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)), CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)), CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id), CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)), CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)), CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)), CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096)), CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE, CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);

-- Permissions

ALTER TABLE auth.oauth_authorizations OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.oauth_authorizations TO postgres;
GRANT ALL ON TABLE auth.oauth_authorizations TO supabase_auth_admin;
GRANT ALL ON TABLE auth.oauth_authorizations TO dashboard_user;


-- auth.oauth_consents definição

-- Drop table

-- DROP TABLE auth.oauth_consents;

CREATE TABLE auth.oauth_consents ( id uuid NOT NULL, user_id uuid NOT NULL, client_id uuid NOT NULL, scopes text NOT NULL, granted_at timestamptz DEFAULT now() NOT NULL, revoked_at timestamptz NULL, CONSTRAINT oauth_consents_pkey PRIMARY KEY (id), CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))), CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)), CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0)), CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id), CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE, CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);
CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);
CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);

-- Permissions

ALTER TABLE auth.oauth_consents OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.oauth_consents TO postgres;
GRANT ALL ON TABLE auth.oauth_consents TO supabase_auth_admin;
GRANT ALL ON TABLE auth.oauth_consents TO dashboard_user;


-- auth.one_time_tokens definição

-- Drop table

-- DROP TABLE auth.one_time_tokens;

CREATE TABLE auth.one_time_tokens ( id uuid NOT NULL, user_id uuid NOT NULL, token_type auth."one_time_token_type" NOT NULL, token_hash text NOT NULL, relates_to text NOT NULL, created_at timestamp DEFAULT now() NOT NULL, updated_at timestamp DEFAULT now() NOT NULL, CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id), CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0)), CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);
CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);
CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);

-- Permissions

ALTER TABLE auth.one_time_tokens OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.one_time_tokens TO postgres;
GRANT ALL ON TABLE auth.one_time_tokens TO supabase_auth_admin;
GRANT ALL ON TABLE auth.one_time_tokens TO dashboard_user;


-- auth.saml_providers definição

-- Drop table

-- DROP TABLE auth.saml_providers;

CREATE TABLE auth.saml_providers ( id uuid NOT NULL, sso_provider_id uuid NOT NULL, entity_id text NOT NULL, metadata_xml text NOT NULL, metadata_url text NULL, attribute_mapping jsonb NULL, created_at timestamptz NULL, updated_at timestamptz NULL, name_id_format text NULL, CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)), CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))), CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0)), CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id), CONSTRAINT saml_providers_pkey PRIMARY KEY (id), CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE);
CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);
COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';

-- Permissions

ALTER TABLE auth.saml_providers OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.saml_providers TO postgres;
GRANT ALL ON TABLE auth.saml_providers TO supabase_auth_admin;
GRANT ALL ON TABLE auth.saml_providers TO dashboard_user;


-- auth.saml_relay_states definição

-- Drop table

-- DROP TABLE auth.saml_relay_states;

CREATE TABLE auth.saml_relay_states ( id uuid NOT NULL, sso_provider_id uuid NOT NULL, request_id text NOT NULL, for_email text NULL, redirect_to text NULL, created_at timestamptz NULL, updated_at timestamptz NULL, flow_state_id uuid NULL, CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0)), CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id), CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE, CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE);
CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);
CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);
CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);
COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';

-- Permissions

ALTER TABLE auth.saml_relay_states OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.saml_relay_states TO postgres;
GRANT ALL ON TABLE auth.saml_relay_states TO supabase_auth_admin;
GRANT ALL ON TABLE auth.saml_relay_states TO dashboard_user;


-- auth.sessions definição

-- Drop table

-- DROP TABLE auth.sessions;

CREATE TABLE auth.sessions ( id uuid NOT NULL, user_id uuid NOT NULL, created_at timestamptz NULL, updated_at timestamptz NULL, factor_id uuid NULL, aal auth."aal_level" NULL, not_after timestamptz NULL, refreshed_at timestamp NULL, user_agent text NULL, ip inet NULL, tag text NULL, oauth_client_id uuid NULL, refresh_token_hmac_key text NULL, refresh_token_counter int8 NULL, scopes text NULL, CONSTRAINT sessions_pkey PRIMARY KEY (id), CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096)), CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE, CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);
CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);
CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);
CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);
COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';

-- Column comments

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';
COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';
COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';

-- Permissions

ALTER TABLE auth.sessions OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.sessions TO postgres;
GRANT ALL ON TABLE auth.sessions TO supabase_auth_admin;
GRANT ALL ON TABLE auth.sessions TO dashboard_user;


-- auth.sso_domains definição

-- Drop table

-- DROP TABLE auth.sso_domains;

CREATE TABLE auth.sso_domains ( id uuid NOT NULL, sso_provider_id uuid NOT NULL, "domain" text NOT NULL, created_at timestamptz NULL, updated_at timestamptz NULL, CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0)), CONSTRAINT sso_domains_pkey PRIMARY KEY (id), CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE);
CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));
CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);
COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';

-- Permissions

ALTER TABLE auth.sso_domains OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.sso_domains TO postgres;
GRANT ALL ON TABLE auth.sso_domains TO supabase_auth_admin;
GRANT ALL ON TABLE auth.sso_domains TO dashboard_user;


-- auth.mfa_amr_claims definição

-- Drop table

-- DROP TABLE auth.mfa_amr_claims;

CREATE TABLE auth.mfa_amr_claims ( session_id uuid NOT NULL, created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL, authentication_method text NOT NULL, id uuid NOT NULL, CONSTRAINT amr_id_pk PRIMARY KEY (id), CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method), CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE);
COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';

-- Permissions

ALTER TABLE auth.mfa_amr_claims OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.mfa_amr_claims TO postgres;
GRANT ALL ON TABLE auth.mfa_amr_claims TO supabase_auth_admin;
GRANT ALL ON TABLE auth.mfa_amr_claims TO dashboard_user;


-- auth.mfa_challenges definição

-- Drop table

-- DROP TABLE auth.mfa_challenges;

CREATE TABLE auth.mfa_challenges ( id uuid NOT NULL, factor_id uuid NOT NULL, created_at timestamptz NOT NULL, verified_at timestamptz NULL, ip_address inet NOT NULL, otp_code text NULL, web_authn_session_data jsonb NULL, CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id), CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE);
CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);
COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';

-- Permissions

ALTER TABLE auth.mfa_challenges OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.mfa_challenges TO postgres;
GRANT ALL ON TABLE auth.mfa_challenges TO supabase_auth_admin;
GRANT ALL ON TABLE auth.mfa_challenges TO dashboard_user;


-- auth.refresh_tokens definição

-- Drop table

-- DROP TABLE auth.refresh_tokens;

CREATE TABLE auth.refresh_tokens ( instance_id uuid NULL, id bigserial NOT NULL, "token" varchar(255) NULL, user_id varchar(255) NULL, revoked bool NULL, created_at timestamptz NULL, updated_at timestamptz NULL, parent varchar(255) NULL, session_id uuid NULL, CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id), CONSTRAINT refresh_tokens_token_unique UNIQUE (token), CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE);
CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);
CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);
CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);
CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);
CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);
COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';

-- Permissions

ALTER TABLE auth.refresh_tokens OWNER TO supabase_auth_admin;
GRANT ALL ON TABLE auth.refresh_tokens TO supabase_auth_admin;
GRANT ALL ON TABLE auth.refresh_tokens TO dashboard_user;
GRANT ALL ON TABLE auth.refresh_tokens TO postgres;



-- DROP FUNCTION auth.email();

CREATE OR REPLACE FUNCTION auth.email()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$function$
;

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';

-- Permissions

ALTER FUNCTION auth.email() OWNER TO supabase_auth_admin;
GRANT ALL ON FUNCTION auth.email() TO public;
GRANT ALL ON FUNCTION auth.email() TO supabase_auth_admin;
GRANT ALL ON FUNCTION auth.email() TO dashboard_user;

-- DROP FUNCTION auth.jwt();

CREATE OR REPLACE FUNCTION auth.jwt()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$function$
;

-- Permissions

ALTER FUNCTION auth.jwt() OWNER TO supabase_auth_admin;
GRANT ALL ON FUNCTION auth.jwt() TO public;
GRANT ALL ON FUNCTION auth.jwt() TO postgres;
GRANT ALL ON FUNCTION auth.jwt() TO supabase_auth_admin;
GRANT ALL ON FUNCTION auth.jwt() TO dashboard_user;

-- DROP FUNCTION auth."role"();

CREATE OR REPLACE FUNCTION auth.role()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$function$
;

COMMENT ON FUNCTION auth."role"() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';

-- Permissions

ALTER FUNCTION auth."role"() OWNER TO supabase_auth_admin;
GRANT ALL ON FUNCTION auth."role"() TO public;
GRANT ALL ON FUNCTION auth."role"() TO supabase_auth_admin;
GRANT ALL ON FUNCTION auth."role"() TO dashboard_user;

-- DROP FUNCTION auth.uid();

CREATE OR REPLACE FUNCTION auth.uid()
 RETURNS uuid
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$function$
;

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';

-- Permissions

ALTER FUNCTION auth.uid() OWNER TO supabase_auth_admin;
GRANT ALL ON FUNCTION auth.uid() TO public;
GRANT ALL ON FUNCTION auth.uid() TO supabase_auth_admin;
GRANT ALL ON FUNCTION auth.uid() TO dashboard_user;


-- Permissions

GRANT ALL ON SCHEMA auth TO supabase_admin;
GRANT USAGE ON SCHEMA auth TO anon;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT USAGE ON SCHEMA auth TO service_role;
GRANT ALL ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON SCHEMA auth TO dashboard_user;
GRANT USAGE ON SCHEMA auth TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT EXECUTE ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT EXECUTE ON FUNCTIONS TO dashboard_user;

-- DROP SCHEMA realtime;

CREATE SCHEMA realtime AUTHORIZATION supabase_admin;

-- DROP TYPE realtime."action";

CREATE TYPE realtime."action" AS ENUM (
	'INSERT',
	'UPDATE',
	'DELETE',
	'TRUNCATE',
	'ERROR');

-- DROP TYPE realtime."equality_op";

CREATE TYPE realtime."equality_op" AS ENUM (
	'eq',
	'neq',
	'lt',
	'lte',
	'gt',
	'gte',
	'in');

-- DROP SEQUENCE realtime.subscription_id_seq;

CREATE SEQUENCE realtime.subscription_id_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 9223372036854775807
	START 1
	CACHE 1
	NO CYCLE;

-- Permissions

ALTER SEQUENCE realtime.subscription_id_seq OWNER TO supabase_admin;
GRANT ALL ON SEQUENCE realtime.subscription_id_seq TO supabase_admin;
GRANT ALL ON SEQUENCE realtime.subscription_id_seq TO postgres;
GRANT ALL ON SEQUENCE realtime.subscription_id_seq TO dashboard_user;
GRANT USAGE ON SEQUENCE realtime.subscription_id_seq TO anon;
GRANT USAGE ON SEQUENCE realtime.subscription_id_seq TO authenticated;
GRANT USAGE ON SEQUENCE realtime.subscription_id_seq TO service_role;
GRANT ALL ON SEQUENCE realtime.subscription_id_seq TO supabase_realtime_admin;
-- realtime.messages definição

-- Drop table

-- DROP TABLE realtime.messages;

CREATE TABLE realtime.messages ( topic text NOT NULL, "extension" text NOT NULL, payload jsonb NULL, "event" text NULL, private bool DEFAULT false NULL, updated_at timestamp DEFAULT now() NOT NULL, inserted_at timestamp DEFAULT now() NOT NULL, id uuid DEFAULT gen_random_uuid() NOT NULL, CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at)) PARTITION BY RANGE (inserted_at);
CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));

-- Permissions

ALTER TABLE realtime.messages OWNER TO supabase_realtime_admin;
GRANT ALL ON TABLE realtime.messages TO supabase_realtime_admin;
GRANT ALL ON TABLE realtime.messages TO postgres;
GRANT ALL ON TABLE realtime.messages TO dashboard_user;
GRANT SELECT, INSERT, UPDATE ON TABLE realtime.messages TO anon;
GRANT SELECT, INSERT, UPDATE ON TABLE realtime.messages TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE realtime.messages TO service_role;


-- realtime.schema_migrations definição

-- Drop table

-- DROP TABLE realtime.schema_migrations;

CREATE TABLE realtime.schema_migrations ( "version" int8 NOT NULL, inserted_at timestamp(0) NULL, CONSTRAINT schema_migrations_pkey PRIMARY KEY (version));

-- Permissions

ALTER TABLE realtime.schema_migrations OWNER TO supabase_admin;
GRANT ALL ON TABLE realtime.schema_migrations TO supabase_admin;
GRANT ALL ON TABLE realtime.schema_migrations TO postgres;
GRANT ALL ON TABLE realtime.schema_migrations TO dashboard_user;
GRANT SELECT ON TABLE realtime.schema_migrations TO anon;
GRANT SELECT ON TABLE realtime.schema_migrations TO authenticated;
GRANT SELECT ON TABLE realtime.schema_migrations TO service_role;
GRANT ALL ON TABLE realtime.schema_migrations TO supabase_realtime_admin;


-- realtime."subscription" definição

-- Drop table

-- DROP TABLE realtime."subscription";

CREATE TABLE realtime."subscription" ( id int8 GENERATED ALWAYS AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START 1 CACHE 1 NO CYCLE) NOT NULL, subscription_id uuid NOT NULL, entity regclass NOT NULL, filters realtime._user_defined_filter DEFAULT '{}'::realtime.user_defined_filter[] NOT NULL, claims jsonb NOT NULL, claims_role regrole GENERATED ALWAYS AS (realtime.to_regrole(claims ->> 'role'::text)) STORED NOT NULL, created_at timestamp DEFAULT timezone('utc'::text, now()) NOT NULL, action_filter text DEFAULT '*'::text NULL, CONSTRAINT pk_subscription PRIMARY KEY (id), CONSTRAINT subscription_action_filter_check CHECK ((action_filter = ANY (ARRAY['*'::text, 'INSERT'::text, 'UPDATE'::text, 'DELETE'::text]))));
CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity);
CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_action_filter_key ON realtime.subscription USING btree (subscription_id, entity, filters, action_filter);

-- Table Triggers

create trigger tr_check_filters before
insert
    or
update
    on
    realtime.subscription for each row execute function realtime.subscription_check_filters();

-- Permissions

ALTER TABLE realtime."subscription" OWNER TO supabase_admin;
GRANT ALL ON TABLE realtime."subscription" TO supabase_admin;
GRANT ALL ON TABLE realtime."subscription" TO postgres;
GRANT ALL ON TABLE realtime."subscription" TO dashboard_user;
GRANT SELECT ON TABLE realtime."subscription" TO anon;
GRANT SELECT ON TABLE realtime."subscription" TO authenticated;
GRANT SELECT ON TABLE realtime."subscription" TO service_role;
GRANT ALL ON TABLE realtime."subscription" TO supabase_realtime_admin;



-- DROP FUNCTION realtime.apply_rls(jsonb, int4);

CREATE OR REPLACE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024))
 RETURNS SETOF realtime.wal_rls
 LANGUAGE plpgsql
AS $function$
declare
-- Regclass of the table e.g. public.notes
entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

-- I, U, D, T: insert, update ...
action realtime.action = (
    case wal ->> 'action'
        when 'I' then 'INSERT'
        when 'U' then 'UPDATE'
        when 'D' then 'DELETE'
        else 'ERROR'
    end
);

-- Is row level security enabled for the table
is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

subscriptions realtime.subscription[] = array_agg(subs)
    from
        realtime.subscription subs
    where
        subs.entity = entity_
        -- Filter by action early - only get subscriptions interested in this action
        -- action_filter column can be: '*' (all), 'INSERT', 'UPDATE', or 'DELETE'
        and (subs.action_filter = '*' or subs.action_filter = action::text);

-- Subscription vars
roles regrole[] = array_agg(distinct us.claims_role::text)
    from
        unnest(subscriptions) us;

working_role regrole;
claimed_role regrole;
claims jsonb;

subscription_id uuid;
subscription_has_access bool;
visible_to_subscription_ids uuid[] = '{}';

-- structured info for wal's columns
columns realtime.wal_column[];
-- previous identity values for update/delete
old_columns realtime.wal_column[];

error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

-- Primary jsonb output for record
output jsonb;

begin
perform set_config('role', null, true);

columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'columns') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

old_columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'identity') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

for working_role in select * from unnest(roles) loop

    -- Update `is_selectable` for columns and old_columns
    columns =
        array_agg(
            (
                c.name,
                c.type_name,
                c.type_oid,
                c.value,
                c.is_pkey,
                pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
            )::realtime.wal_column
        )
        from
            unnest(columns) c;

    old_columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(old_columns) c;

    if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            -- subscriptions is already filtered by entity
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 400: Bad Request, no primary key']
        )::realtime.wal_rls;

    -- The claims role does not have SELECT permission to the primary key of entity
    elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 401: Unauthorized']
        )::realtime.wal_rls;

    else
        output = jsonb_build_object(
            'schema', wal ->> 'schema',
            'table', wal ->> 'table',
            'type', action,
            'commit_timestamp', to_char(
                ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
            ),
            'columns', (
                select
                    jsonb_agg(
                        jsonb_build_object(
                            'name', pa.attname,
                            'type', pt.typname
                        )
                        order by pa.attnum asc
                    )
                from
                    pg_attribute pa
                    join pg_type pt
                        on pa.atttypid = pt.oid
                where
                    attrelid = entity_
                    and attnum > 0
                    and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
            )
        )
        -- Add "record" key for insert and update
        || case
            when action in ('INSERT', 'UPDATE') then
                jsonb_build_object(
                    'record',
                    (
                        select
                            jsonb_object_agg(
                                -- if unchanged toast, get column name and value from old record
                                coalesce((c).name, (oc).name),
                                case
                                    when (c).name is null then (oc).value
                                    else (c).value
                                end
                            )
                        from
                            unnest(columns) c
                            full outer join unnest(old_columns) oc
                                on (c).name = (oc).name
                        where
                            coalesce((c).is_selectable, (oc).is_selectable)
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                    )
                )
            else '{}'::jsonb
        end
        -- Add "old_record" key for update and delete
        || case
            when action = 'UPDATE' then
                jsonb_build_object(
                        'old_record',
                        (
                            select jsonb_object_agg((c).name, (c).value)
                            from unnest(old_columns) c
                            where
                                (c).is_selectable
                                and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                        )
                    )
            when action = 'DELETE' then
                jsonb_build_object(
                    'old_record',
                    (
                        select jsonb_object_agg((c).name, (c).value)
                        from unnest(old_columns) c
                        where
                            (c).is_selectable
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                    )
                )
            else '{}'::jsonb
        end;

        -- Create the prepared statement
        if is_rls_enabled and action <> 'DELETE' then
            if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                deallocate walrus_rls_stmt;
            end if;
            execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
        end if;

        visible_to_subscription_ids = '{}';

        for subscription_id, claims in (
                select
                    subs.subscription_id,
                    subs.claims
                from
                    unnest(subscriptions) subs
                where
                    subs.entity = entity_
                    and subs.claims_role = working_role
                    and (
                        realtime.is_visible_through_filters(columns, subs.filters)
                        or (
                          action = 'DELETE'
                          and realtime.is_visible_through_filters(old_columns, subs.filters)
                        )
                    )
        ) loop

            if not is_rls_enabled or action = 'DELETE' then
                visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
            else
                -- Check if RLS allows the role to see the record
                perform
                    -- Trim leading and trailing quotes from working_role because set_config
                    -- doesn't recognize the role as valid if they are included
                    set_config('role', trim(both '"' from working_role::text), true),
                    set_config('request.jwt.claims', claims::text, true);

                execute 'execute walrus_rls_stmt' into subscription_has_access;

                if subscription_has_access then
                    visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
                end if;
            end if;
        end loop;

        perform set_config('role', null, true);

        return next (
            output,
            is_rls_enabled,
            visible_to_subscription_ids,
            case
                when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                else '{}'
            end
        )::realtime.wal_rls;

    end if;
end loop;

perform set_config('role', null, true);
end;
$function$
;

-- Permissions

ALTER FUNCTION realtime.apply_rls(jsonb, int4) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime.apply_rls(jsonb, int4) TO public;
GRANT ALL ON FUNCTION realtime.apply_rls(jsonb, int4) TO supabase_admin;
GRANT ALL ON FUNCTION realtime.apply_rls(jsonb, int4) TO postgres;
GRANT ALL ON FUNCTION realtime.apply_rls(jsonb, int4) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.apply_rls(jsonb, int4) TO anon;
GRANT ALL ON FUNCTION realtime.apply_rls(jsonb, int4) TO authenticated;
GRANT ALL ON FUNCTION realtime.apply_rls(jsonb, int4) TO service_role;
GRANT ALL ON FUNCTION realtime.apply_rls(jsonb, int4) TO supabase_realtime_admin;

-- DROP FUNCTION realtime.broadcast_changes(text, text, text, text, text, record, record, text);

CREATE OR REPLACE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$function$
;

-- Permissions

ALTER FUNCTION realtime.broadcast_changes(text, text, text, text, text, record, record, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime.broadcast_changes(text, text, text, text, text, record, record, text) TO public;
GRANT ALL ON FUNCTION realtime.broadcast_changes(text, text, text, text, text, record, record, text) TO supabase_admin;
GRANT ALL ON FUNCTION realtime.broadcast_changes(text, text, text, text, text, record, record, text) TO postgres;
GRANT ALL ON FUNCTION realtime.broadcast_changes(text, text, text, text, text, record, record, text) TO dashboard_user;

-- DROP FUNCTION realtime.build_prepared_statement_sql(text, regclass, realtime._wal_column);

CREATE OR REPLACE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[])
 RETURNS text
 LANGUAGE sql
AS $function$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $function$
;

-- Permissions

ALTER FUNCTION realtime.build_prepared_statement_sql(text, regclass, realtime._wal_column) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(text, regclass, realtime._wal_column) TO public;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(text, regclass, realtime._wal_column) TO supabase_admin;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(text, regclass, realtime._wal_column) TO postgres;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(text, regclass, realtime._wal_column) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(text, regclass, realtime._wal_column) TO anon;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(text, regclass, realtime._wal_column) TO authenticated;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(text, regclass, realtime._wal_column) TO service_role;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(text, regclass, realtime._wal_column) TO supabase_realtime_admin;

-- DROP FUNCTION realtime."cast"(text, regtype);

CREATE OR REPLACE FUNCTION realtime."cast"(val text, type_ regtype)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
    declare
      res jsonb;
    begin
      execute format('select to_jsonb(%L::'|| type_::text || ')', val)  into res;
      return res;
    end
    $function$
;

-- Permissions

ALTER FUNCTION realtime."cast"(text, regtype) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime."cast"(text, regtype) TO public;
GRANT ALL ON FUNCTION realtime."cast"(text, regtype) TO supabase_admin;
GRANT ALL ON FUNCTION realtime."cast"(text, regtype) TO postgres;
GRANT ALL ON FUNCTION realtime."cast"(text, regtype) TO dashboard_user;
GRANT ALL ON FUNCTION realtime."cast"(text, regtype) TO anon;
GRANT ALL ON FUNCTION realtime."cast"(text, regtype) TO authenticated;
GRANT ALL ON FUNCTION realtime."cast"(text, regtype) TO service_role;
GRANT ALL ON FUNCTION realtime."cast"(text, regtype) TO supabase_realtime_admin;

-- DROP FUNCTION realtime.check_equality_op(realtime."equality_op", regtype, text, text);

CREATE OR REPLACE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
      /*
      Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
      */
      declare
          op_symbol text = (
              case
                  when op = 'eq' then '='
                  when op = 'neq' then '!='
                  when op = 'lt' then '<'
                  when op = 'lte' then '<='
                  when op = 'gt' then '>'
                  when op = 'gte' then '>='
                  when op = 'in' then '= any'
                  else 'UNKNOWN OP'
              end
          );
          res boolean;
      begin
          execute format(
              'select %L::'|| type_::text || ' ' || op_symbol
              || ' ( %L::'
              || (
                  case
                      when op = 'in' then type_::text || '[]'
                      else type_::text end
              )
              || ')', val_1, val_2) into res;
          return res;
      end;
      $function$
;

-- Permissions

ALTER FUNCTION realtime.check_equality_op(realtime."equality_op", regtype, text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime.check_equality_op(realtime."equality_op", regtype, text, text) TO public;
GRANT ALL ON FUNCTION realtime.check_equality_op(realtime."equality_op", regtype, text, text) TO supabase_admin;
GRANT ALL ON FUNCTION realtime.check_equality_op(realtime."equality_op", regtype, text, text) TO postgres;
GRANT ALL ON FUNCTION realtime.check_equality_op(realtime."equality_op", regtype, text, text) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.check_equality_op(realtime."equality_op", regtype, text, text) TO anon;
GRANT ALL ON FUNCTION realtime.check_equality_op(realtime."equality_op", regtype, text, text) TO authenticated;
GRANT ALL ON FUNCTION realtime.check_equality_op(realtime."equality_op", regtype, text, text) TO service_role;
GRANT ALL ON FUNCTION realtime.check_equality_op(realtime."equality_op", regtype, text, text) TO supabase_realtime_admin;

-- DROP FUNCTION realtime.is_visible_through_filters(realtime._wal_column, realtime._user_defined_filter);

CREATE OR REPLACE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[])
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$
    /*
    Should the record be visible (true) or filtered out (false) after *filters* are applied
    */
        select
            -- Default to allowed when no filters present
            $2 is null -- no filters. this should not happen because subscriptions has a default
            or array_length($2, 1) is null -- array length of an empty array is null
            or bool_and(
                coalesce(
                    realtime.check_equality_op(
                        op:=f.op,
                        type_:=coalesce(
                            col.type_oid::regtype, -- null when wal2json version <= 2.4
                            col.type_name::regtype
                        ),
                        -- cast jsonb to text
                        val_1:=col.value #>> '{}',
                        val_2:=f.value
                    ),
                    false -- if null, filter does not match
                )
            )
        from
            unnest(filters) f
            join unnest(columns) col
                on f.column_name = col.name;
    $function$
;

-- Permissions

ALTER FUNCTION realtime.is_visible_through_filters(realtime._wal_column, realtime._user_defined_filter) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(realtime._wal_column, realtime._user_defined_filter) TO public;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(realtime._wal_column, realtime._user_defined_filter) TO supabase_admin;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(realtime._wal_column, realtime._user_defined_filter) TO postgres;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(realtime._wal_column, realtime._user_defined_filter) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(realtime._wal_column, realtime._user_defined_filter) TO anon;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(realtime._wal_column, realtime._user_defined_filter) TO authenticated;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(realtime._wal_column, realtime._user_defined_filter) TO service_role;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(realtime._wal_column, realtime._user_defined_filter) TO supabase_realtime_admin;

-- DROP FUNCTION realtime.list_changes(name, name, int4, int4);

CREATE OR REPLACE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer)
 RETURNS SETOF realtime.wal_rls
 LANGUAGE sql
 SET log_min_messages TO 'fatal'
AS $function$
      with pub as (
        select
          concat_ws(
            ',',
            case when bool_or(pubinsert) then 'insert' else null end,
            case when bool_or(pubupdate) then 'update' else null end,
            case when bool_or(pubdelete) then 'delete' else null end
          ) as w2j_actions,
          coalesce(
            string_agg(
              realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
              ','
            ) filter (where ppt.tablename is not null and ppt.tablename not like '% %'),
            ''
          ) w2j_add_tables
        from
          pg_publication pp
          left join pg_publication_tables ppt
            on pp.pubname = ppt.pubname
        where
          pp.pubname = publication
        group by
          pp.pubname
        limit 1
      ),
      w2j as (
        select
          x.*, pub.w2j_add_tables
        from
          pub,
          pg_logical_slot_get_changes(
            slot_name, null, max_changes,
            'include-pk', 'true',
            'include-transaction', 'false',
            'include-timestamp', 'true',
            'include-type-oids', 'true',
            'format-version', '2',
            'actions', pub.w2j_actions,
            'add-tables', pub.w2j_add_tables
          ) x
      )
      select
        xyz.wal,
        xyz.is_rls_enabled,
        xyz.subscription_ids,
        xyz.errors
      from
        w2j,
        realtime.apply_rls(
          wal := w2j.data::jsonb,
          max_record_bytes := max_record_bytes
        ) xyz(wal, is_rls_enabled, subscription_ids, errors)
      where
        w2j.w2j_add_tables <> ''
        and xyz.subscription_ids[1] is not null
    $function$
;

-- Permissions

ALTER FUNCTION realtime.list_changes(name, name, int4, int4) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime.list_changes(name, name, int4, int4) TO public;
GRANT ALL ON FUNCTION realtime.list_changes(name, name, int4, int4) TO supabase_admin;
GRANT ALL ON FUNCTION realtime.list_changes(name, name, int4, int4) TO postgres;
GRANT ALL ON FUNCTION realtime.list_changes(name, name, int4, int4) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.list_changes(name, name, int4, int4) TO anon;
GRANT ALL ON FUNCTION realtime.list_changes(name, name, int4, int4) TO authenticated;
GRANT ALL ON FUNCTION realtime.list_changes(name, name, int4, int4) TO service_role;
GRANT ALL ON FUNCTION realtime.list_changes(name, name, int4, int4) TO supabase_realtime_admin;

-- DROP FUNCTION realtime.quote_wal2json(regclass);

CREATE OR REPLACE FUNCTION realtime.quote_wal2json(entity regclass)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE STRICT
AS $function$
      select
        (
          select string_agg('' || ch,'')
          from unnest(string_to_array(nsp.nspname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
        )
        || '.'
        || (
          select string_agg('' || ch,'')
          from unnest(string_to_array(pc.relname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
          )
      from
        pg_class pc
        join pg_namespace nsp
          on pc.relnamespace = nsp.oid
      where
        pc.oid = entity
    $function$
;

-- Permissions

ALTER FUNCTION realtime.quote_wal2json(regclass) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime.quote_wal2json(regclass) TO public;
GRANT ALL ON FUNCTION realtime.quote_wal2json(regclass) TO supabase_admin;
GRANT ALL ON FUNCTION realtime.quote_wal2json(regclass) TO postgres;
GRANT ALL ON FUNCTION realtime.quote_wal2json(regclass) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.quote_wal2json(regclass) TO anon;
GRANT ALL ON FUNCTION realtime.quote_wal2json(regclass) TO authenticated;
GRANT ALL ON FUNCTION realtime.quote_wal2json(regclass) TO service_role;
GRANT ALL ON FUNCTION realtime.quote_wal2json(regclass) TO supabase_realtime_admin;

-- DROP FUNCTION realtime.send(jsonb, text, text, bool);

CREATE OR REPLACE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    -- Generate a new UUID for the id
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    -- Attempt to insert the message
    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      -- Capture and notify the error
      RAISE WARNING 'ErrorSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$function$
;

-- Permissions

ALTER FUNCTION realtime.send(jsonb, text, text, bool) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime.send(jsonb, text, text, bool) TO public;
GRANT ALL ON FUNCTION realtime.send(jsonb, text, text, bool) TO supabase_admin;
GRANT ALL ON FUNCTION realtime.send(jsonb, text, text, bool) TO postgres;
GRANT ALL ON FUNCTION realtime.send(jsonb, text, text, bool) TO dashboard_user;

-- DROP FUNCTION realtime.subscription_check_filters();

CREATE OR REPLACE FUNCTION realtime.subscription_check_filters()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
    /*
    Validates that the user defined filters for a subscription:
    - refer to valid columns that the claimed role may access
    - values are coercable to the correct column type
    */
    declare
        col_names text[] = coalesce(
                array_agg(c.column_name order by c.ordinal_position),
                '{}'::text[]
            )
            from
                information_schema.columns c
            where
                format('%I.%I', c.table_schema, c.table_name)::regclass = new.entity
                and pg_catalog.has_column_privilege(
                    (new.claims ->> 'role'),
                    format('%I.%I', c.table_schema, c.table_name)::regclass,
                    c.column_name,
                    'SELECT'
                );
        filter realtime.user_defined_filter;
        col_type regtype;

        in_val jsonb;
    begin
        for filter in select * from unnest(new.filters) loop
            -- Filtered column is valid
            if not filter.column_name = any(col_names) then
                raise exception 'invalid column for filter %', filter.column_name;
            end if;

            -- Type is sanitized and safe for string interpolation
            col_type = (
                select atttypid::regtype
                from pg_catalog.pg_attribute
                where attrelid = new.entity
                      and attname = filter.column_name
            );
            if col_type is null then
                raise exception 'failed to lookup type for column %', filter.column_name;
            end if;

            -- Set maximum number of entries for in filter
            if filter.op = 'in'::realtime.equality_op then
                in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
                if coalesce(jsonb_array_length(in_val), 0) > 100 then
                    raise exception 'too many values for `in` filter. Maximum 100';
                end if;
            else
                -- raises an exception if value is not coercable to type
                perform realtime.cast(filter.value, col_type);
            end if;

        end loop;

        -- Apply consistent order to filters so the unique constraint on
        -- (subscription_id, entity, filters) can't be tricked by a different filter order
        new.filters = coalesce(
            array_agg(f order by f.column_name, f.op, f.value),
            '{}'
        ) from unnest(new.filters) f;

        return new;
    end;
    $function$
;

-- Permissions

ALTER FUNCTION realtime.subscription_check_filters() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO public;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO supabase_admin;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO postgres;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO dashboard_user;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO anon;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO authenticated;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO service_role;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO supabase_realtime_admin;

-- DROP FUNCTION realtime.to_regrole(text);

CREATE OR REPLACE FUNCTION realtime.to_regrole(role_name text)
 RETURNS regrole
 LANGUAGE sql
 IMMUTABLE
AS $function$ select role_name::regrole $function$
;

-- Permissions

ALTER FUNCTION realtime.to_regrole(text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION realtime.to_regrole(text) TO public;
GRANT ALL ON FUNCTION realtime.to_regrole(text) TO supabase_admin;
GRANT ALL ON FUNCTION realtime.to_regrole(text) TO postgres;
GRANT ALL ON FUNCTION realtime.to_regrole(text) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.to_regrole(text) TO anon;
GRANT ALL ON FUNCTION realtime.to_regrole(text) TO authenticated;
GRANT ALL ON FUNCTION realtime.to_regrole(text) TO service_role;
GRANT ALL ON FUNCTION realtime.to_regrole(text) TO supabase_realtime_admin;

-- DROP FUNCTION realtime.topic();

CREATE OR REPLACE FUNCTION realtime.topic()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
select nullif(current_setting('realtime.topic', true), '')::text;
$function$
;

-- Permissions

ALTER FUNCTION realtime.topic() OWNER TO supabase_realtime_admin;
GRANT ALL ON FUNCTION realtime.topic() TO public;
GRANT ALL ON FUNCTION realtime.topic() TO supabase_realtime_admin;
GRANT ALL ON FUNCTION realtime.topic() TO postgres;
GRANT ALL ON FUNCTION realtime.topic() TO dashboard_user;


-- Permissions

GRANT ALL ON SCHEMA realtime TO supabase_admin;
GRANT USAGE ON SCHEMA realtime TO postgres;
GRANT USAGE ON SCHEMA realtime TO anon;
GRANT USAGE ON SCHEMA realtime TO authenticated;
GRANT USAGE ON SCHEMA realtime TO service_role;
GRANT ALL ON SCHEMA realtime TO supabase_realtime_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT EXECUTE ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT EXECUTE ON FUNCTIONS TO dashboard_user;

-- DROP SCHEMA "storage";

CREATE SCHEMA "storage" AUTHORIZATION supabase_admin;

-- DROP TYPE "storage"."buckettype";

CREATE TYPE "storage"."buckettype" AS ENUM (
	'STANDARD',
	'ANALYTICS',
	'VECTOR');
-- "storage".buckets definição

-- Drop table

-- DROP TABLE "storage".buckets;

CREATE TABLE "storage".buckets ( id text NOT NULL, "name" text NOT NULL, "owner" uuid NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, public bool DEFAULT false NULL, avif_autodetection bool DEFAULT false NULL, file_size_limit int8 NULL, allowed_mime_types _text NULL, owner_id text NULL, "type" "storage"."buckettype" DEFAULT 'STANDARD'::storage.buckettype NOT NULL, CONSTRAINT buckets_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);

-- Column comments

COMMENT ON COLUMN "storage".buckets."owner" IS 'Field is deprecated, use owner_id instead';

-- Table Triggers

create trigger enforce_bucket_name_length_trigger before
insert
    or
update
    of name on
    storage.buckets for each row execute function storage.enforce_bucket_name_length();
create trigger protect_buckets_delete before
delete
    on
    storage.buckets for each statement execute function storage.protect_delete();

-- Permissions

ALTER TABLE "storage".buckets OWNER TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".buckets TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".buckets TO service_role;
GRANT ALL ON TABLE "storage".buckets TO authenticated;
GRANT ALL ON TABLE "storage".buckets TO anon;
GRANT ALL ON TABLE "storage".buckets TO postgres;


-- "storage".buckets_analytics definição

-- Drop table

-- DROP TABLE "storage".buckets_analytics;

CREATE TABLE "storage".buckets_analytics ( "name" text NOT NULL, "type" "storage"."buckettype" DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL, format text DEFAULT 'ICEBERG'::text NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, id uuid DEFAULT gen_random_uuid() NOT NULL, deleted_at timestamptz NULL, CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);

-- Permissions

ALTER TABLE "storage".buckets_analytics OWNER TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".buckets_analytics TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".buckets_analytics TO service_role;
GRANT ALL ON TABLE "storage".buckets_analytics TO authenticated;
GRANT ALL ON TABLE "storage".buckets_analytics TO anon;


-- "storage".buckets_vectors definição

-- Drop table

-- DROP TABLE "storage".buckets_vectors;

CREATE TABLE "storage".buckets_vectors ( id text NOT NULL, "type" "storage"."buckettype" DEFAULT 'VECTOR'::storage.buckettype NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id));

-- Permissions

ALTER TABLE "storage".buckets_vectors OWNER TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".buckets_vectors TO supabase_storage_admin;
GRANT SELECT ON TABLE "storage".buckets_vectors TO service_role;
GRANT SELECT ON TABLE "storage".buckets_vectors TO authenticated;
GRANT SELECT ON TABLE "storage".buckets_vectors TO anon;


-- "storage".migrations definição

-- Drop table

-- DROP TABLE "storage".migrations;

CREATE TABLE "storage".migrations ( id int4 NOT NULL, "name" varchar(100) NOT NULL, hash varchar(40) NOT NULL, executed_at timestamp DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT migrations_name_key UNIQUE (name), CONSTRAINT migrations_pkey PRIMARY KEY (id));

-- Permissions

ALTER TABLE "storage".migrations OWNER TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".migrations TO supabase_storage_admin;


-- "storage".objects definição

-- Drop table

-- DROP TABLE "storage".objects;

CREATE TABLE "storage".objects ( id uuid DEFAULT gen_random_uuid() NOT NULL, bucket_id text NULL, "name" text NULL, "owner" uuid NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, last_accessed_at timestamptz DEFAULT now() NULL, metadata jsonb NULL, path_tokens _text GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED NULL, "version" text NULL, owner_id text NULL, user_metadata jsonb NULL, CONSTRAINT objects_pkey PRIMARY KEY (id), CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES "storage".buckets(id));
CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);
CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");
CREATE INDEX idx_objects_bucket_id_name_lower ON storage.objects USING btree (bucket_id, lower(name) COLLATE "C");
CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);

-- Column comments

COMMENT ON COLUMN "storage".objects."owner" IS 'Field is deprecated, use owner_id instead';

-- Table Triggers

create trigger protect_objects_delete before
delete
    on
    storage.objects for each statement execute function storage.protect_delete();
create trigger update_objects_updated_at before
update
    on
    storage.objects for each row execute function storage.update_updated_at_column();

-- Permissions

ALTER TABLE "storage".objects OWNER TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".objects TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".objects TO service_role;
GRANT ALL ON TABLE "storage".objects TO authenticated;
GRANT ALL ON TABLE "storage".objects TO anon;
GRANT ALL ON TABLE "storage".objects TO postgres;


-- "storage".s3_multipart_uploads definição

-- Drop table

-- DROP TABLE "storage".s3_multipart_uploads;

CREATE TABLE "storage".s3_multipart_uploads ( id text NOT NULL, in_progress_size int8 DEFAULT 0 NOT NULL, upload_signature text NOT NULL, bucket_id text NOT NULL, "key" text COLLATE "C" NOT NULL, "version" text NOT NULL, owner_id text NULL, created_at timestamptz DEFAULT now() NOT NULL, user_metadata jsonb NULL, CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id), CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES "storage".buckets(id));
CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);

-- Permissions

ALTER TABLE "storage".s3_multipart_uploads OWNER TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".s3_multipart_uploads TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".s3_multipart_uploads TO service_role;
GRANT SELECT ON TABLE "storage".s3_multipart_uploads TO authenticated;
GRANT SELECT ON TABLE "storage".s3_multipart_uploads TO anon;


-- "storage".s3_multipart_uploads_parts definição

-- Drop table

-- DROP TABLE "storage".s3_multipart_uploads_parts;

CREATE TABLE "storage".s3_multipart_uploads_parts ( id uuid DEFAULT gen_random_uuid() NOT NULL, upload_id text NOT NULL, "size" int8 DEFAULT 0 NOT NULL, part_number int4 NOT NULL, bucket_id text NOT NULL, "key" text COLLATE "C" NOT NULL, etag text NOT NULL, owner_id text NULL, "version" text NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id), CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES "storage".buckets(id), CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES "storage".s3_multipart_uploads(id) ON DELETE CASCADE);

-- Permissions

ALTER TABLE "storage".s3_multipart_uploads_parts OWNER TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".s3_multipart_uploads_parts TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".s3_multipart_uploads_parts TO service_role;
GRANT SELECT ON TABLE "storage".s3_multipart_uploads_parts TO authenticated;
GRANT SELECT ON TABLE "storage".s3_multipart_uploads_parts TO anon;


-- "storage".vector_indexes definição

-- Drop table

-- DROP TABLE "storage".vector_indexes;

CREATE TABLE "storage".vector_indexes ( id text DEFAULT gen_random_uuid() NOT NULL, "name" text COLLATE "C" NOT NULL, bucket_id text NOT NULL, data_type text NOT NULL, dimension int4 NOT NULL, distance_metric text NOT NULL, metadata_configuration jsonb NULL, created_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT vector_indexes_pkey PRIMARY KEY (id), CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES "storage".buckets_vectors(id));
CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);

-- Permissions

ALTER TABLE "storage".vector_indexes OWNER TO supabase_storage_admin;
GRANT ALL ON TABLE "storage".vector_indexes TO supabase_storage_admin;
GRANT SELECT ON TABLE "storage".vector_indexes TO service_role;
GRANT SELECT ON TABLE "storage".vector_indexes TO authenticated;
GRANT SELECT ON TABLE "storage".vector_indexes TO anon;



-- DROP FUNCTION "storage".can_insert_object(text, text, uuid, jsonb);

CREATE OR REPLACE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$function$
;

-- Permissions

ALTER FUNCTION "storage".can_insert_object(text, text, uuid, jsonb) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".can_insert_object(text, text, uuid, jsonb) TO supabase_storage_admin;

-- DROP FUNCTION "storage".delete_leaf_prefixes(_text, _text);

CREATE OR REPLACE FUNCTION storage.delete_leaf_prefixes(bucket_ids text[], names text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_rows_deleted integer;
BEGIN
    LOOP
        WITH candidates AS (
            SELECT DISTINCT
                t.bucket_id,
                unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        ),
        uniq AS (
             SELECT
                 bucket_id,
                 name,
                 storage.get_level(name) AS level
             FROM candidates
             WHERE name <> ''
             GROUP BY bucket_id, name
        ),
        leaf AS (
             SELECT
                 p.bucket_id,
                 p.name,
                 p.level
             FROM storage.prefixes AS p
                  JOIN uniq AS u
                       ON u.bucket_id = p.bucket_id
                           AND u.name = p.name
                           AND u.level = p.level
             WHERE NOT EXISTS (
                 SELECT 1
                 FROM storage.objects AS o
                 WHERE o.bucket_id = p.bucket_id
                   AND o.level = p.level + 1
                   AND o.name COLLATE "C" LIKE p.name || '/%'
             )
             AND NOT EXISTS (
                 SELECT 1
                 FROM storage.prefixes AS c
                 WHERE c.bucket_id = p.bucket_id
                   AND c.level = p.level + 1
                   AND c.name COLLATE "C" LIKE p.name || '/%'
             )
        )
        DELETE
        FROM storage.prefixes AS p
            USING leaf AS l
        WHERE p.bucket_id = l.bucket_id
          AND p.name = l.name
          AND p.level = l.level;

        GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
        EXIT WHEN v_rows_deleted = 0;
    END LOOP;
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".delete_leaf_prefixes(_text, _text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".delete_leaf_prefixes(_text, _text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".enforce_bucket_name_length();

CREATE OR REPLACE FUNCTION storage.enforce_bucket_name_length()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$function$
;

-- Permissions

ALTER FUNCTION "storage".enforce_bucket_name_length() OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".enforce_bucket_name_length() TO supabase_storage_admin;

-- DROP FUNCTION "storage"."extension"(text);

CREATE OR REPLACE FUNCTION storage.extension(name text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    SELECT _parts[array_length(_parts,1)] INTO _filename;
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$function$
;

-- Permissions

ALTER FUNCTION "storage"."extension"(text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage"."extension"(text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".filename(text);

CREATE OR REPLACE FUNCTION storage.filename(name text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$function$
;

-- Permissions

ALTER FUNCTION "storage".filename(text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".filename(text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".foldername(text);

CREATE OR REPLACE FUNCTION storage.foldername(name text)
 RETURNS text[]
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$function$
;

-- Permissions

ALTER FUNCTION "storage".foldername(text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".foldername(text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".get_common_prefix(text, text, text);

CREATE OR REPLACE FUNCTION storage.get_common_prefix(p_key text, p_prefix text, p_delimiter text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
SELECT CASE
    WHEN position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(p_key, length(p_prefix) + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)))
    ELSE NULL
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".get_common_prefix(text, text, text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".get_common_prefix(text, text, text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".get_level(text);

CREATE OR REPLACE FUNCTION storage.get_level(name text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE STRICT
AS $function$
SELECT array_length(string_to_array("name", '/'), 1);
$function$
;

-- Permissions

ALTER FUNCTION "storage".get_level(text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".get_level(text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".get_prefix(text);

CREATE OR REPLACE FUNCTION storage.get_prefix(name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE STRICT
AS $function$
SELECT
    CASE WHEN strpos("name", '/') > 0 THEN
             regexp_replace("name", '[\/]{1}[^\/]+\/?$', '')
         ELSE
             ''
        END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".get_prefix(text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".get_prefix(text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".get_prefixes(text);

CREATE OR REPLACE FUNCTION storage.get_prefixes(name text)
 RETURNS text[]
 LANGUAGE plpgsql
 IMMUTABLE STRICT
AS $function$
DECLARE
    parts text[];
    prefixes text[];
    prefix text;
BEGIN
    -- Split the name into parts by '/'
    parts := string_to_array("name", '/');
    prefixes := '{}';

    -- Construct the prefixes, stopping one level below the last part
    FOR i IN 1..array_length(parts, 1) - 1 LOOP
            prefix := array_to_string(parts[1:i], '/');
            prefixes := array_append(prefixes, prefix);
    END LOOP;

    RETURN prefixes;
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".get_prefixes(text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".get_prefixes(text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".get_size_by_bucket();

CREATE OR REPLACE FUNCTION storage.get_size_by_bucket()
 RETURNS TABLE(size bigint, bucket_id text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    return query
        select sum((metadata->>'size')::bigint) as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$function$
;

-- Permissions

ALTER FUNCTION "storage".get_size_by_bucket() OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".get_size_by_bucket() TO supabase_storage_admin;

-- DROP FUNCTION "storage".list_multipart_uploads_with_delimiter(text, text, text, int4, text, text);

CREATE OR REPLACE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text)
 RETURNS TABLE(key text, id text, created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".list_multipart_uploads_with_delimiter(text, text, text, int4, text, text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".list_multipart_uploads_with_delimiter(text, text, text, int4, text, text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".list_objects_with_delimiter(text, text, text, int4, text, text, text);

CREATE OR REPLACE FUNCTION storage.list_objects_with_delimiter(_bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text)
 RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix, 1) = delimiter_param THEN
        v_upper_bound := left(v_prefix, -1) || chr(ascii(delimiter_param) + 1);
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'AND o.name COLLATE "C" < $3 ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'AND o.name COLLATE "C" >= $3 ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor: find the last item in range
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Cursor provided: determine if it refers to a folder or leaf
        IF EXISTS (
            SELECT 1 FROM storage.objects o
            WHERE o.bucket_id = _bucket_id
              AND o.name COLLATE "C" LIKE v_start || delimiter_param || '%'
            LIMIT 1
        ) THEN
            -- Cursor refers to a folder
            IF v_is_asc THEN
                v_next_seek := v_start || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_start || delimiter_param;
            END IF;
        ELSE
            -- Cursor refers to a leaf object
            IF v_is_asc THEN
                v_next_seek := v_start || delimiter_param;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := rtrim(v_common_prefix, delimiter_param);
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1) || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := v_current.name;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                RETURN NEXT;
                v_count := v_count + 1;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := v_current.name || delimiter_param;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;
    END LOOP;
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".list_objects_with_delimiter(text, text, text, int4, text, text, text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".list_objects_with_delimiter(text, text, text, int4, text, text, text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".operation();

CREATE OR REPLACE FUNCTION storage.operation()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".operation() OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".operation() TO supabase_storage_admin;

-- DROP FUNCTION "storage".protect_delete();

CREATE OR REPLACE FUNCTION storage.protect_delete()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".protect_delete() OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".protect_delete() TO supabase_storage_admin;

-- DROP FUNCTION "storage"."search"(text, text, int4, int4, int4, text, text, text);

CREATE OR REPLACE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text)
 RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;
    v_skipped INT := 0;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach (unchanged)
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT path_tokens[$1] AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $2 || '%%'
                  AND bucket_id = $3
                  AND array_length(objects.path_tokens, 1) <> $1
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata FROM folders)
            UNION ALL
            (SELECT path_tokens[$1] AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata
             FROM storage.objects
             WHERE objects.name ILIKE $2 || '%%'
               AND bucket_id = $3
               AND array_length(objects.path_tokens, 1) = $1
             ORDER BY %I %s)
            LIMIT $4 OFFSET $5
            $sql$, v_sort_order, v_order_by, v_sort_order
        ) USING levels, v_prefix, bucketname, v_limit, offsets;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'AND lower(o.name) COLLATE "C" < $3 ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'AND lower(o.name) COLLATE "C" >= $3 ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC: find the last item in range first (static SQL)
        IF v_upper_bound IS NOT NULL THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower AND lower(o.name) COLLATE "C" < v_upper_bound
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSIF v_prefix_lower <> '' THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSE
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        END IF;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix_lower <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := split_part(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter), v_delimiter, levels);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := lower(v_current.name);
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := split_part(v_current.name, v_delimiter, levels);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := lower(v_current.name) || v_delimiter;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;
    END LOOP;
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage"."search"(text, text, int4, int4, int4, text, text, text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage"."search"(text, text, int4, int4, int4, text, text, text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".search_by_timestamp(text, text, int4, int4, text, text, text, text);

CREATE OR REPLACE FUNCTION storage.search_by_timestamp(p_prefix text, p_bucket_id text, p_limit integer, p_level integer, p_start_after text, p_sort_order text, p_sort_column text, p_sort_column_after text)
 RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
BEGIN
    v_prefix := coalesce(p_prefix, '');

    IF p_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $1 || '%%'
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                rtrim(common_prefix, '/') AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    date_trunc('milliseconds', %I),
                    name COLLATE "C"
                ) %s ROW(
                    COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz),
                    $5
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s
        LIMIT $4
    $sql$,
        p_sort_column,
        v_cursor_op,
        p_sort_column,
        p_sort_order,
        p_sort_order
    );

    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after;
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".search_by_timestamp(text, text, int4, int4, text, text, text, text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".search_by_timestamp(text, text, int4, int4, text, text, text, text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".search_legacy_v1(text, text, int4, int4, int4, text, text, text);

CREATE OR REPLACE FUNCTION storage.search_legacy_v1(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text)
 RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select path_tokens[$1] as folder
           from storage.objects
             where objects.name ilike $2 || $3 || ''%''
               and bucket_id = $4
               and array_length(objects.path_tokens, 1) <> $1
           group by folder
           order by folder ' || v_sort_order || '
     )
     (select folder as "name",
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[$1] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where objects.name ilike $2 || $3 || ''%''
       and bucket_id = $4
       and array_length(objects.path_tokens, 1) = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$function$
;

-- Permissions

ALTER FUNCTION "storage".search_legacy_v1(text, text, int4, int4, int4, text, text, text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".search_legacy_v1(text, text, int4, int4, int4, text, text, text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".search_v2(text, text, int4, int4, text, text, text, text);

CREATE OR REPLACE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text)
 RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            start_after,
            '',
            v_sort_ord
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after
        );
    END IF;
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".search_v2(text, text, int4, int4, text, text, text, text) OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".search_v2(text, text, int4, int4, text, text, text, text) TO supabase_storage_admin;

-- DROP FUNCTION "storage".update_updated_at_column();

CREATE OR REPLACE FUNCTION storage.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$function$
;

-- Permissions

ALTER FUNCTION "storage".update_updated_at_column() OWNER TO supabase_storage_admin;
GRANT ALL ON FUNCTION "storage".update_updated_at_column() TO supabase_storage_admin;


-- Permissions

GRANT ALL ON SCHEMA "storage" TO supabase_admin;
GRANT USAGE ON SCHEMA "storage" TO postgres WITH GRANT OPTION;
GRANT USAGE ON SCHEMA "storage" TO anon;
GRANT USAGE ON SCHEMA "storage" TO authenticated;
GRANT USAGE ON SCHEMA "storage" TO service_role;
GRANT ALL ON SCHEMA "storage" TO supabase_storage_admin;
GRANT ALL ON SCHEMA "storage" TO dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT MAINTAIN, SELECT, TRUNCATE, INSERT, REFERENCES, DELETE, TRIGGER, UPDATE ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT EXECUTE ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT EXECUTE ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT EXECUTE ON FUNCTIONS TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "storage" GRANT SELECT, USAGE, UPDATE ON SEQUENCES TO service_role;

-- DROP SCHEMA vault;

CREATE SCHEMA vault AUTHORIZATION supabase_admin;
-- vault.secrets definição

-- Drop table

-- DROP TABLE vault.secrets;

CREATE TABLE vault.secrets ( id uuid DEFAULT gen_random_uuid() NOT NULL, "name" text NULL, description text DEFAULT ''::text NOT NULL, secret text NOT NULL, key_id uuid NULL, nonce bytea DEFAULT vault._crypto_aead_det_noncegen() NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, CONSTRAINT secrets_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX secrets_name_idx ON vault.secrets USING btree (name) WHERE (name IS NOT NULL);
COMMENT ON TABLE vault.secrets IS 'Table with encrypted `secret` column for storing sensitive information on disk.';

-- Permissions

ALTER TABLE vault.secrets OWNER TO supabase_admin;
GRANT ALL ON TABLE vault.secrets TO supabase_admin;
GRANT SELECT, TRUNCATE, REFERENCES, DELETE ON TABLE vault.secrets TO postgres WITH GRANT OPTION;
GRANT SELECT, DELETE ON TABLE vault.secrets TO service_role;


-- vault.decrypted_secrets fonte

CREATE OR REPLACE VIEW vault.decrypted_secrets
AS SELECT id,
    name,
    description,
    secret,
    convert_from(vault._crypto_aead_det_decrypt(message => decode(secret, 'base64'::text), additional => convert_to(id::text, 'utf8'::name), key_id => 0::bigint, context => '\x7067736f6469756d'::bytea, nonce => nonce), 'utf8'::name) AS decrypted_secret,
    key_id,
    nonce,
    created_at,
    updated_at
   FROM vault.secrets s;

-- Permissions

ALTER TABLE vault.decrypted_secrets OWNER TO supabase_admin;
GRANT ALL ON TABLE vault.decrypted_secrets TO supabase_admin;
GRANT SELECT, TRUNCATE, REFERENCES, DELETE ON TABLE vault.decrypted_secrets TO postgres WITH GRANT OPTION;
GRANT SELECT, DELETE ON TABLE vault.decrypted_secrets TO service_role;



-- DROP FUNCTION vault._crypto_aead_det_decrypt(bytea, bytea, int8, bytea, bytea);

CREATE OR REPLACE FUNCTION vault._crypto_aead_det_decrypt(message bytea, additional bytea, key_id bigint, context bytea DEFAULT '\x7067736f6469756d'::bytea, nonce bytea DEFAULT NULL::bytea)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE
AS '$libdir/supabase_vault', $function$pgsodium_crypto_aead_det_decrypt_by_id$function$
;

-- Permissions

ALTER FUNCTION vault._crypto_aead_det_decrypt(bytea, bytea, int8, bytea, bytea) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION vault._crypto_aead_det_decrypt(bytea, bytea, int8, bytea, bytea) TO supabase_admin;
GRANT ALL ON FUNCTION vault._crypto_aead_det_decrypt(bytea, bytea, int8, bytea, bytea) TO postgres;
GRANT ALL ON FUNCTION vault._crypto_aead_det_decrypt(bytea, bytea, int8, bytea, bytea) TO service_role;

-- DROP FUNCTION vault._crypto_aead_det_encrypt(bytea, bytea, int8, bytea, bytea);

CREATE OR REPLACE FUNCTION vault._crypto_aead_det_encrypt(message bytea, additional bytea, key_id bigint, context bytea DEFAULT '\x7067736f6469756d'::bytea, nonce bytea DEFAULT NULL::bytea)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE
AS '$libdir/supabase_vault', $function$pgsodium_crypto_aead_det_encrypt_by_id$function$
;

-- Permissions

ALTER FUNCTION vault._crypto_aead_det_encrypt(bytea, bytea, int8, bytea, bytea) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION vault._crypto_aead_det_encrypt(bytea, bytea, int8, bytea, bytea) TO supabase_admin;

-- DROP FUNCTION vault._crypto_aead_det_noncegen();

CREATE OR REPLACE FUNCTION vault._crypto_aead_det_noncegen()
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE
AS '$libdir/supabase_vault', $function$pgsodium_crypto_aead_det_noncegen$function$
;

-- Permissions

ALTER FUNCTION vault._crypto_aead_det_noncegen() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION vault._crypto_aead_det_noncegen() TO supabase_admin;

-- DROP FUNCTION vault.create_secret(text, text, text, uuid);

CREATE OR REPLACE FUNCTION vault.create_secret(new_secret text, new_name text DEFAULT NULL::text, new_description text DEFAULT ''::text, new_key_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  rec record;
BEGIN
  INSERT INTO vault.secrets (secret, name, description)
  VALUES (
    new_secret,
    new_name,
    new_description
  )
  RETURNING * INTO rec;
  UPDATE vault.secrets s
  SET secret = encode(vault._crypto_aead_det_encrypt(
    message := convert_to(rec.secret, 'utf8'),
    additional := convert_to(s.id::text, 'utf8'),
    key_id := 0,
    context := 'pgsodium'::bytea,
    nonce := rec.nonce
  ), 'base64')
  WHERE id = rec.id;
  RETURN rec.id;
END
$function$
;

-- Permissions

ALTER FUNCTION vault.create_secret(text, text, text, uuid) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION vault.create_secret(text, text, text, uuid) TO supabase_admin;
GRANT ALL ON FUNCTION vault.create_secret(text, text, text, uuid) TO postgres;
GRANT ALL ON FUNCTION vault.create_secret(text, text, text, uuid) TO service_role;

-- DROP FUNCTION vault.update_secret(uuid, text, text, text, uuid);

CREATE OR REPLACE FUNCTION vault.update_secret(secret_id uuid, new_secret text DEFAULT NULL::text, new_name text DEFAULT NULL::text, new_description text DEFAULT NULL::text, new_key_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  decrypted_secret text := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE id = secret_id);
BEGIN
  UPDATE vault.secrets s
  SET
    secret = CASE WHEN new_secret IS NULL THEN s.secret
                  ELSE encode(vault._crypto_aead_det_encrypt(
                    message := convert_to(new_secret, 'utf8'),
                    additional := convert_to(s.id::text, 'utf8'),
                    key_id := 0,
                    context := 'pgsodium'::bytea,
                    nonce := s.nonce
                  ), 'base64') END,
    name = coalesce(new_name, s.name),
    description = coalesce(new_description, s.description),
    updated_at = now()
  WHERE s.id = secret_id;
END
$function$
;

-- Permissions

ALTER FUNCTION vault.update_secret(uuid, text, text, text, uuid) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION vault.update_secret(uuid, text, text, text, uuid) TO supabase_admin;
GRANT ALL ON FUNCTION vault.update_secret(uuid, text, text, text, uuid) TO postgres;
GRANT ALL ON FUNCTION vault.update_secret(uuid, text, text, text, uuid) TO service_role;


-- Permissions

GRANT ALL ON SCHEMA vault TO supabase_admin;
GRANT USAGE ON SCHEMA vault TO postgres WITH GRANT OPTION;
GRANT USAGE ON SCHEMA vault TO service_role;