SET session_replication_role = replica;

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."audit_log_entries" ("instance_id", "id", "payload", "created_at", "ip_address") VALUES
	('00000000-0000-0000-0000-000000000000', '7ba28967-f529-4718-826f-7ad756e6c360', '{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"admin@gsdm.cl","user_id":"448cc15a-b364-443b-b347-6adb4d8229a1","user_phone":""}}', '2025-11-04 01:25:07.278607+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e702dd4c-4aab-4786-9c4e-39cee8ec5919', '{"action":"login","actor_id":"448cc15a-b364-443b-b347-6adb4d8229a1","actor_username":"admin@gsdm.cl","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-04 01:25:46.836369+00', ''),
	('00000000-0000-0000-0000-000000000000', '7b21bd2f-638b-4f23-bee9-4fcbc5cc6bd4', '{"action":"logout","actor_id":"448cc15a-b364-443b-b347-6adb4d8229a1","actor_username":"admin@gsdm.cl","actor_via_sso":false,"log_type":"account"}', '2025-11-04 01:27:05.330922+00', ''),
	('00000000-0000-0000-0000-000000000000', '3f146930-109a-44d7-a091-d9e71707f85e', '{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"admin@gmail.com","user_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","user_phone":""}}', '2025-12-11 00:29:04.1587+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b1510025-19c9-4ee9-ae22-d4522ffb7fea', '{"action":"login","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-12-11 00:29:30.263603+00', ''),
	('00000000-0000-0000-0000-000000000000', '7d6df260-267b-400f-bb16-f1ae092c0da6', '{"action":"token_refreshed","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-11 01:31:39.539209+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd17f7db5-0d53-4c77-b16d-82525e922f85', '{"action":"token_revoked","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-11 01:31:39.548469+00', ''),
	('00000000-0000-0000-0000-000000000000', '14b1324f-44ab-4b25-a6aa-a1658b714f51', '{"action":"token_refreshed","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-15 23:06:56.326107+00', ''),
	('00000000-0000-0000-0000-000000000000', 'acf65953-f0be-44c0-8ddf-68d2b5d05589', '{"action":"token_revoked","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-15 23:06:56.345386+00', ''),
	('00000000-0000-0000-0000-000000000000', '7dea0887-3fed-4660-84a0-b3830a05066b', '{"action":"login","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-12-16 00:15:06.014226+00', ''),
	('00000000-0000-0000-0000-000000000000', '58f2a492-ad0f-4a43-9830-b6f7413f1dc4', '{"action":"login","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-12-16 01:18:29.349105+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f869ce88-3c70-44c0-850a-56d07b4fa747', '{"action":"logout","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-12-16 01:19:59.128625+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b524b461-8648-4f4e-b293-3590a4f0f5b8', '{"action":"login","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-12-16 01:20:07.643824+00', ''),
	('00000000-0000-0000-0000-000000000000', '12e56444-c307-402a-bbb7-23aa826d82ca', '{"action":"token_refreshed","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-16 13:58:24.746717+00', ''),
	('00000000-0000-0000-0000-000000000000', '6861bd4b-ae08-43d1-a2a4-dfab2a5f69a0', '{"action":"token_revoked","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-16 13:58:24.757997+00', ''),
	('00000000-0000-0000-0000-000000000000', '8a8d881f-77ed-4568-b9ec-28ba3691c6e8', '{"action":"token_refreshed","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-16 19:42:19.95416+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c69ff27a-7056-45a3-9c3f-fa61b1c71df4', '{"action":"token_revoked","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-16 19:42:19.97543+00', ''),
	('00000000-0000-0000-0000-000000000000', '6807d09a-dffa-4b9d-9949-c2121614f2c2', '{"action":"token_refreshed","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-17 01:21:32.148441+00', ''),
	('00000000-0000-0000-0000-000000000000', '4aeb319c-df9b-4b8b-bb52-8b912bc3d479', '{"action":"token_revoked","actor_id":"cfc26a9b-3b50-4b6e-8776-04456334083a","actor_username":"admin@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-17 01:21:32.158206+00', ''),
	('00000000-0000-0000-0000-000000000000', '919d0b51-2f33-4b0f-bdba-2fb4195dcd10', '{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"user@gsdm.cl","user_id":"4f27afce-fb57-408e-af26-52429129554b","user_phone":""}}', '2025-12-19 18:30:15.706106+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b18de467-e621-476b-9dad-ca0a39237c8b', '{"action":"login","actor_id":"4f27afce-fb57-408e-af26-52429129554b","actor_username":"user@gsdm.cl","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-12-19 18:31:08.82955+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd72d0aaa-02e0-4b80-9fd6-5cef7aeca373', '{"action":"token_refreshed","actor_id":"4f27afce-fb57-408e-af26-52429129554b","actor_username":"user@gsdm.cl","actor_via_sso":false,"log_type":"token"}', '2025-12-19 19:29:42.657727+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b727e2b5-abab-41f2-b644-ea47e19010f5', '{"action":"token_revoked","actor_id":"4f27afce-fb57-408e-af26-52429129554b","actor_username":"user@gsdm.cl","actor_via_sso":false,"log_type":"token"}', '2025-12-19 19:29:42.675842+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b95e0fee-7889-469b-ad94-8c167db97711', '{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"prueba@gmail.com","user_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","user_phone":""}}', '2025-12-28 19:40:39.659052+00', ''),
	('00000000-0000-0000-0000-000000000000', '362c039a-156d-4990-975e-7d61d5650db6', '{"action":"login","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-12-28 19:41:04.686593+00', ''),
	('00000000-0000-0000-0000-000000000000', '11f06586-a581-4a02-8234-2469d421dbec', '{"action":"token_refreshed","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-28 21:03:59.96119+00', ''),
	('00000000-0000-0000-0000-000000000000', '4e3f3d14-4ecb-4d3a-b637-16a2efbafd7f', '{"action":"token_revoked","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-28 21:03:59.98346+00', ''),
	('00000000-0000-0000-0000-000000000000', '7ffcbf73-3e09-44b5-8e41-f4d81a4b6b15', '{"action":"token_refreshed","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-28 22:03:10.529447+00', ''),
	('00000000-0000-0000-0000-000000000000', 'caaa8c77-a5c7-47de-93dd-88991eb2e27a', '{"action":"token_revoked","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-28 22:03:10.548194+00', ''),
	('00000000-0000-0000-0000-000000000000', 'ff02db0e-873b-4449-bb17-35a3d4eb8d9d', '{"action":"token_refreshed","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-28 23:02:39.515832+00', ''),
	('00000000-0000-0000-0000-000000000000', 'fba63942-fcda-4d01-9cb2-2c2e5111b01a', '{"action":"token_revoked","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-28 23:02:39.527679+00', ''),
	('00000000-0000-0000-0000-000000000000', 'be416553-38c4-4f82-b410-49b7caa0bea1', '{"action":"token_refreshed","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-29 00:01:31.04604+00', ''),
	('00000000-0000-0000-0000-000000000000', '0d3b7724-bb0c-4da5-ae23-8538cf46f150', '{"action":"token_revoked","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-29 00:01:31.054156+00', ''),
	('00000000-0000-0000-0000-000000000000', '4603b0f3-842c-4281-9fa7-aceafc388daf', '{"action":"token_refreshed","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-30 00:59:48.626312+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd81f0abc-c846-4e36-ac98-c9c0e6179285', '{"action":"token_revoked","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-12-30 00:59:48.647409+00', ''),
	('00000000-0000-0000-0000-000000000000', 'fd76e7ac-4c75-46da-9783-ecc7fa8aaf9a', '{"action":"login","actor_id":"065bb9e4-5053-43cf-9bed-7f9104c42810","actor_username":"prueba@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-12-30 01:50:54.657329+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c652f387-6e6f-400e-a73e-b062a228b632', '{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"adminsuper@gmai.cl","user_id":"aae75c27-6f6a-4ef5-a622-239226b1e8f9","user_phone":""}}', '2026-01-06 01:42:29.076322+00', ''),
	('00000000-0000-0000-0000-000000000000', '444a4c5a-4e50-477a-9cdf-9c284a0a7952', '{"action":"login","actor_id":"aae75c27-6f6a-4ef5-a622-239226b1e8f9","actor_username":"adminsuper@gmai.cl","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2026-01-06 01:43:18.486221+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e9a210fd-cbf2-41de-9356-896fe67be6b5', '{"action":"token_refreshed","actor_id":"aae75c27-6f6a-4ef5-a622-239226b1e8f9","actor_username":"adminsuper@gmai.cl","actor_via_sso":false,"log_type":"token"}', '2026-01-17 01:00:07.104332+00', ''),
	('00000000-0000-0000-0000-000000000000', 'ccc6035e-b04f-4d32-9782-b864d8514aff', '{"action":"token_revoked","actor_id":"aae75c27-6f6a-4ef5-a622-239226b1e8f9","actor_username":"adminsuper@gmai.cl","actor_via_sso":false,"log_type":"token"}', '2026-01-17 01:00:07.112588+00', '');


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."users" ("instance_id", "id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "invited_at", "confirmation_token", "confirmation_sent_at", "recovery_token", "recovery_sent_at", "email_change_token_new", "email_change", "email_change_sent_at", "last_sign_in_at", "raw_app_meta_data", "raw_user_meta_data", "is_super_admin", "created_at", "updated_at", "phone", "phone_confirmed_at", "phone_change", "phone_change_token", "phone_change_sent_at", "email_change_token_current", "email_change_confirm_status", "banned_until", "reauthentication_token", "reauthentication_sent_at", "is_sso_user", "deleted_at", "is_anonymous") VALUES
	('00000000-0000-0000-0000-000000000000', 'eb098169-1c0f-4690-b3bc-88172332f7d9', NULL, 'authenticated', 'admin@hospital.cl', '$2a$06$YjVfAGlfOCL6UdS47iBV8.CJeKVuNAJO5LOkZ7O/cTryo9roEWGAG', '2025-12-11 00:27:41.964395+00', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{"provider": "email", "providers": ["email"]}', '{"name": "Administrador Sistema"}', false, '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '1a561abd-ff05-4c22-bd44-77cb2eb07962', NULL, 'authenticated', 'bodega@hospital.cl', '$2a$06$Gqig.nd.xc8K586QWjWx8uTsKwPDSQVGibn2o9gVM7f3y/jtNdVce', '2025-12-11 00:27:41.964395+00', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{"provider": "email", "providers": ["email"]}', '{"name": "Encargado Bodega"}', false, '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '448cc15a-b364-443b-b347-6adb4d8229a1', 'authenticated', 'authenticated', 'admin@gsdm.cl', '$2a$10$aOlh8adkzpyt9kiI7fLaNe1OQgCHPSn1c0pzFW8vpqGqPsCc4g4Tq', '2025-11-04 01:25:07.285266+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-04 01:25:46.838555+00', '{"provider": "email", "providers": ["email"]}', '{"email_verified": true}', NULL, '2025-11-04 01:25:07.262306+00', '2025-11-04 01:25:46.856027+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '50d87701-4d4f-41cd-b93b-2d6bad5d8aac', NULL, 'authenticated', 'auditor@hospital.cl', '$2a$06$xQpaZxWLLiyAX9ppUS0tYeI.tdOdR49/oODkqyo/U65/xBEvSQ9ZO', '2025-12-11 00:27:41.964395+00', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{"provider": "email", "providers": ["email"]}', '{"name": "Auditor Interno"}', false, '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', 'aed9422e-4149-4c21-ba9f-4f88ed959353', NULL, 'authenticated', 'enfermero@hospital.cl', '$2a$06$iXtVbVPAbGMISG55JV3r4uv/Y6.HOtFih4.86.z3.oQ0.fVLp0yXq', '2025-12-11 00:27:41.964395+00', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{"provider": "email", "providers": ["email"]}', '{"name": "Enfermero Jefe"}', false, '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', 'c35a707d-a23c-490f-b2e5-b0b34235828e', NULL, 'authenticated', 'viewer@hospital.cl', '$2a$06$wByPMAezr4sdl7Rbmuw/.ONUpSJ0IeZZZNr8uWceseJUKzlcKBWBm', '2025-12-11 00:27:41.964395+00', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{"provider": "email", "providers": ["email"]}', '{"name": "Visualizador"}', false, '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '4f27afce-fb57-408e-af26-52429129554b', 'authenticated', 'authenticated', 'user@gsdm.cl', '$2a$10$DUrzKBkllHSy6ry6K4ACaeLAnWv1z91//oVN06zPTdy3jswUhoCQO', '2025-12-19 18:30:15.714594+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-12-19 18:31:08.837298+00', '{"provider": "email", "providers": ["email"]}', '{"email_verified": true}', NULL, '2025-12-19 18:30:15.685544+00', '2025-12-19 19:29:42.704981+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', 'aae75c27-6f6a-4ef5-a622-239226b1e8f9', 'authenticated', 'authenticated', 'adminsuper@gmai.cl', '$2a$10$91JdXbJdfc5BwBp/XCC4nuUEOStJ10l450HyLsLhla3li8yqnPiHe', '2026-01-06 01:42:29.084655+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-01-06 01:43:18.489519+00', '{"provider": "email", "providers": ["email"]}', '{"email_verified": true}', NULL, '2026-01-06 01:42:29.05599+00', '2026-01-17 01:00:07.119201+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', 'cfc26a9b-3b50-4b6e-8776-04456334083a', 'authenticated', 'authenticated', 'admin@gmail.com', '$2a$10$AijSO/3.rFySHuO8GYGJWOdTc7oj79FsJEaW9SeHa0jpQju/mrFQm', '2025-12-11 00:29:04.166188+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-12-16 01:20:07.645216+00', '{"provider": "email", "providers": ["email"]}', '{"email_verified": true}', NULL, '2025-12-11 00:29:04.137861+00', '2025-12-17 01:21:32.174337+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'authenticated', 'authenticated', 'prueba@gmail.com', '$2a$10$8jTtBimCrgxe/hqYI1/p6.vbibsQPjP5/4t9GLeUWQh8f8FwYUCjy', '2025-12-28 19:40:39.666534+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-12-30 01:50:54.664565+00', '{"provider": "email", "providers": ["email"]}', '{"email_verified": true}', NULL, '2025-12-28 19:40:39.634393+00', '2025-12-30 01:50:54.679259+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."identities" ("provider_id", "user_id", "identity_data", "provider", "last_sign_in_at", "created_at", "updated_at", "id") VALUES
	('448cc15a-b364-443b-b347-6adb4d8229a1', '448cc15a-b364-443b-b347-6adb4d8229a1', '{"sub": "448cc15a-b364-443b-b347-6adb4d8229a1", "email": "admin@gsdm.cl", "email_verified": false, "phone_verified": false}', 'email', '2025-11-04 01:25:07.274345+00', '2025-11-04 01:25:07.275637+00', '2025-11-04 01:25:07.275637+00', 'ca6b97e5-4143-4726-9ee2-46708b53c83f'),
	('cfc26a9b-3b50-4b6e-8776-04456334083a', 'cfc26a9b-3b50-4b6e-8776-04456334083a', '{"sub": "cfc26a9b-3b50-4b6e-8776-04456334083a", "email": "admin@gmail.com", "email_verified": false, "phone_verified": false}', 'email', '2025-12-11 00:29:04.154257+00', '2025-12-11 00:29:04.154803+00', '2025-12-11 00:29:04.154803+00', '1c436b86-2a4b-466e-bd9b-7718e5adaf5b'),
	('4f27afce-fb57-408e-af26-52429129554b', '4f27afce-fb57-408e-af26-52429129554b', '{"sub": "4f27afce-fb57-408e-af26-52429129554b", "email": "user@gsdm.cl", "email_verified": false, "phone_verified": false}', 'email', '2025-12-19 18:30:15.702531+00', '2025-12-19 18:30:15.702601+00', '2025-12-19 18:30:15.702601+00', 'c4f2745d-72e7-4153-bfd2-7d46c1392039'),
	('065bb9e4-5053-43cf-9bed-7f9104c42810', '065bb9e4-5053-43cf-9bed-7f9104c42810', '{"sub": "065bb9e4-5053-43cf-9bed-7f9104c42810", "email": "prueba@gmail.com", "email_verified": false, "phone_verified": false}', 'email', '2025-12-28 19:40:39.654114+00', '2025-12-28 19:40:39.654178+00', '2025-12-28 19:40:39.654178+00', 'fad5f4d8-f435-4cb1-8c70-c0c8ff98c13c'),
	('aae75c27-6f6a-4ef5-a622-239226b1e8f9', 'aae75c27-6f6a-4ef5-a622-239226b1e8f9', '{"sub": "aae75c27-6f6a-4ef5-a622-239226b1e8f9", "email": "adminsuper@gmai.cl", "email_verified": false, "phone_verified": false}', 'email', '2026-01-06 01:42:29.0733+00', '2026-01-06 01:42:29.073365+00', '2026-01-06 01:42:29.073365+00', 'a45452d2-76a9-4a09-ae13-c1eae83e4815');


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."sessions" ("id", "user_id", "created_at", "updated_at", "factor_id", "aal", "not_after", "refreshed_at", "user_agent", "ip", "tag", "oauth_client_id", "refresh_token_hmac_key", "refresh_token_counter", "scopes") VALUES
	('79b56338-9d18-41b0-a98f-1aeead4eaf90', 'cfc26a9b-3b50-4b6e-8776-04456334083a', '2025-12-16 01:20:07.645326+00', '2025-12-17 01:21:32.182459+00', NULL, 'aal1', NULL, '2025-12-17 01:21:32.182352', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36', '190.89.42.194', NULL, NULL, NULL, NULL, NULL),
	('0958f2e4-47f0-4bda-b79c-ac0f97063071', '4f27afce-fb57-408e-af26-52429129554b', '2025-12-19 18:31:08.837407+00', '2025-12-19 19:29:42.713579+00', NULL, 'aal1', NULL, '2025-12-19 19:29:42.713473', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36', '190.89.42.194', NULL, NULL, NULL, NULL, NULL),
	('36c55e3f-8de4-480c-9641-641d79044733', '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 19:41:04.688386+00', '2025-12-30 00:59:48.687756+00', NULL, 'aal1', NULL, '2025-12-30 00:59:48.687655', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36', '190.89.42.194', NULL, NULL, NULL, NULL, NULL),
	('49e87ce1-0196-4521-88a6-bc1eecbc2c57', '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-30 01:50:54.664683+00', '2025-12-30 01:50:54.664683+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36', '190.89.42.194', NULL, NULL, NULL, NULL, NULL),
	('a044c9f2-fbde-4640-92c1-aaba6c74eec7', 'aae75c27-6f6a-4ef5-a622-239226b1e8f9', '2026-01-06 01:43:18.48963+00', '2026-01-17 01:00:07.122362+00', NULL, 'aal1', NULL, '2026-01-17 01:00:07.122255', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36', '190.89.42.194', NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."mfa_amr_claims" ("session_id", "created_at", "updated_at", "authentication_method", "id") VALUES
	('79b56338-9d18-41b0-a98f-1aeead4eaf90', '2025-12-16 01:20:07.648172+00', '2025-12-16 01:20:07.648172+00', 'password', 'ef12301b-8c7f-478d-9dce-effa027cc8eb'),
	('0958f2e4-47f0-4bda-b79c-ac0f97063071', '2025-12-19 18:31:08.888433+00', '2025-12-19 18:31:08.888433+00', 'password', '636f724a-a493-45b0-8a5a-48082f11d4b7'),
	('36c55e3f-8de4-480c-9641-641d79044733', '2025-12-28 19:41:04.70335+00', '2025-12-28 19:41:04.70335+00', 'password', '7a9f534f-e05e-4f3f-b22b-24ccc33f797a'),
	('49e87ce1-0196-4521-88a6-bc1eecbc2c57', '2025-12-30 01:50:54.680556+00', '2025-12-30 01:50:54.680556+00', 'password', '7c2f02f3-2f9e-4759-af51-768bb6a0e6ea'),
	('a044c9f2-fbde-4640-92c1-aaba6c74eec7', '2026-01-06 01:43:18.508723+00', '2026-01-06 01:43:18.508723+00', 'password', 'dd3e64d9-3a52-4fb8-8912-e2aef2bd89cd');


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."refresh_tokens" ("instance_id", "id", "token", "user_id", "revoked", "created_at", "updated_at", "parent", "session_id") VALUES
	('00000000-0000-0000-0000-000000000000', 7, 'uvpx4aemvlhv', 'cfc26a9b-3b50-4b6e-8776-04456334083a', true, '2025-12-16 01:20:07.646394+00', '2025-12-16 13:58:24.761211+00', NULL, '79b56338-9d18-41b0-a98f-1aeead4eaf90'),
	('00000000-0000-0000-0000-000000000000', 8, 'apoadyef6f34', 'cfc26a9b-3b50-4b6e-8776-04456334083a', true, '2025-12-16 13:58:24.771796+00', '2025-12-16 19:42:19.976174+00', 'uvpx4aemvlhv', '79b56338-9d18-41b0-a98f-1aeead4eaf90'),
	('00000000-0000-0000-0000-000000000000', 9, '3z2wq6e4ptew', 'cfc26a9b-3b50-4b6e-8776-04456334083a', true, '2025-12-16 19:42:19.992228+00', '2025-12-17 01:21:32.158846+00', 'apoadyef6f34', '79b56338-9d18-41b0-a98f-1aeead4eaf90'),
	('00000000-0000-0000-0000-000000000000', 10, 'henbzxkk45aa', 'cfc26a9b-3b50-4b6e-8776-04456334083a', false, '2025-12-17 01:21:32.168151+00', '2025-12-17 01:21:32.168151+00', '3z2wq6e4ptew', '79b56338-9d18-41b0-a98f-1aeead4eaf90'),
	('00000000-0000-0000-0000-000000000000', 11, 'i4btmbtah4wt', '4f27afce-fb57-408e-af26-52429129554b', true, '2025-12-19 18:31:08.86355+00', '2025-12-19 19:29:42.67651+00', NULL, '0958f2e4-47f0-4bda-b79c-ac0f97063071'),
	('00000000-0000-0000-0000-000000000000', 12, 'bszzxoqci3i7', '4f27afce-fb57-408e-af26-52429129554b', false, '2025-12-19 19:29:42.696642+00', '2025-12-19 19:29:42.696642+00', 'i4btmbtah4wt', '0958f2e4-47f0-4bda-b79c-ac0f97063071'),
	('00000000-0000-0000-0000-000000000000', 13, 'gpe6rfkl6imf', '065bb9e4-5053-43cf-9bed-7f9104c42810', true, '2025-12-28 19:41:04.694684+00', '2025-12-28 21:03:59.984947+00', NULL, '36c55e3f-8de4-480c-9641-641d79044733'),
	('00000000-0000-0000-0000-000000000000', 14, 'xswamkzgytrx', '065bb9e4-5053-43cf-9bed-7f9104c42810', true, '2025-12-28 21:04:00.006057+00', '2025-12-28 22:03:10.550226+00', 'gpe6rfkl6imf', '36c55e3f-8de4-480c-9641-641d79044733'),
	('00000000-0000-0000-0000-000000000000', 15, 'mrhqeema23vh', '065bb9e4-5053-43cf-9bed-7f9104c42810', true, '2025-12-28 22:03:10.563753+00', '2025-12-28 23:02:39.528811+00', 'xswamkzgytrx', '36c55e3f-8de4-480c-9641-641d79044733'),
	('00000000-0000-0000-0000-000000000000', 16, 'l5uwcba3blqf', '065bb9e4-5053-43cf-9bed-7f9104c42810', true, '2025-12-28 23:02:39.546424+00', '2025-12-29 00:01:31.054878+00', 'mrhqeema23vh', '36c55e3f-8de4-480c-9641-641d79044733'),
	('00000000-0000-0000-0000-000000000000', 17, 'wo7gkosjrfon', '065bb9e4-5053-43cf-9bed-7f9104c42810', true, '2025-12-29 00:01:31.060113+00', '2025-12-30 00:59:48.64812+00', 'l5uwcba3blqf', '36c55e3f-8de4-480c-9641-641d79044733'),
	('00000000-0000-0000-0000-000000000000', 18, 'o7r6ev2l5i3i', '065bb9e4-5053-43cf-9bed-7f9104c42810', false, '2025-12-30 00:59:48.67027+00', '2025-12-30 00:59:48.67027+00', 'wo7gkosjrfon', '36c55e3f-8de4-480c-9641-641d79044733'),
	('00000000-0000-0000-0000-000000000000', 19, '7hzawxlbeuea', '065bb9e4-5053-43cf-9bed-7f9104c42810', false, '2025-12-30 01:50:54.671096+00', '2025-12-30 01:50:54.671096+00', NULL, '49e87ce1-0196-4521-88a6-bc1eecbc2c57'),
	('00000000-0000-0000-0000-000000000000', 20, 'i7sbpet7n6ms', 'aae75c27-6f6a-4ef5-a622-239226b1e8f9', true, '2026-01-06 01:43:18.497162+00', '2026-01-17 01:00:07.113327+00', NULL, 'a044c9f2-fbde-4640-92c1-aaba6c74eec7'),
	('00000000-0000-0000-0000-000000000000', 21, 'tfjz2tvy7hdb', 'aae75c27-6f6a-4ef5-a622-239226b1e8f9', false, '2026-01-17 01:00:07.116554+00', '2026-01-17 01:00:07.116554+00', 'i7sbpet7n6ms', 'a044c9f2-fbde-4640-92c1-aaba6c74eec7');


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."users" ("id", "email", "name", "role", "created_at", "updated_at") VALUES
	('eb098169-1c0f-4690-b3bc-88172332f7d9', 'admin@hospital.cl', 'Administrador Sistema', 'admin', '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00'),
	('1a561abd-ff05-4c22-bd44-77cb2eb07962', 'bodega@hospital.cl', 'Encargado Bodega', 'bodega', '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00'),
	('50d87701-4d4f-41cd-b93b-2d6bad5d8aac', 'auditor@hospital.cl', 'Auditor Interno', 'auditor', '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00'),
	('aed9422e-4149-4c21-ba9f-4f88ed959353', 'enfermero@hospital.cl', 'Enfermero Jefe', 'enfermero', '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00'),
	('c35a707d-a23c-490f-b2e5-b0b34235828e', 'viewer@hospital.cl', 'Visualizador', 'visualizador', '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00'),
	('cfc26a9b-3b50-4b6e-8776-04456334083a', 'admin@gmail.com', 'Prueba', 'admin', '2025-12-11 00:29:04.135491+00', '2025-12-11 00:29:04.135491+00'),
	('4f27afce-fb57-408e-af26-52429129554b', 'user@gsdm.cl', 'Encargado de local', 'admin', '2025-12-19 18:30:15.685178+00', '2025-12-19 18:30:15.685178+00'),
	('065bb9e4-5053-43cf-9bed-7f9104c42810', 'prueba@gmail.com', 'Encargado Bodega', 'admin', '2025-12-28 19:40:39.632956+00', '2025-12-28 19:40:39.632956+00'),
	('aae75c27-6f6a-4ef5-a622-239226b1e8f9', 'adminsuper@gmai.cl', 'Administrador', 'admin', '2026-01-06 01:42:29.054891+00', '2026-01-06 01:42:29.054891+00');


--
-- Data for Name: auditorias_checklist; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: auditoria_preguntas; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: cajas; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."cajas" ("id", "nombre", "activo", "created_at") VALUES
	('70d6fb81-58f9-4d6b-b4e1-ab13f02ee360', 'Caja 1', true, '2025-12-16 00:01:53.709811+00'),
	('c6f98490-7ef0-4fe9-9e3a-976e085aa804', 'Caja 2', true, '2025-12-16 00:01:53.709811+00');


--
-- Data for Name: categorias; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."categorias" ("id", "nombre", "descripcion", "activo", "created_at") VALUES
	('58c101ae-1400-4b74-aaaa-984ade693f78', 'Almacén', 'Productos generales de despensa', true, '2025-12-16 01:06:28.95143+00'),
	('8668de04-bb62-46e2-8347-5de7ada22144', 'Bebidas', 'Bebidas, jugos y aguas', true, '2025-12-16 01:06:28.95143+00'),
	('d8ad1089-d221-49cb-ae5f-80d1336ffba4', 'Lácteos', 'Leche, yogurt, quesos', true, '2025-12-16 01:06:28.95143+00'),
	('7fdfc82b-6417-43cf-8dd5-e3e4ee1a7c5a', 'Carnes', 'Carnes rojas, blancas y pescados', true, '2025-12-16 01:06:28.95143+00'),
	('00826f3c-5b2e-41f4-8bb2-e3ce509ad46e', 'Verduras y Frutas', 'Productos frescos', true, '2025-12-16 01:06:28.95143+00'),
	('ee855be5-7975-49cb-bc96-d2dc77359b60', 'Limpieza', 'Artículos de aseo y limpieza', true, '2025-12-16 01:06:28.95143+00'),
	('1d3e0b9d-0c5d-4c28-8fc4-7e28312e0b2c', 'Panadería y Pastelería', 'Pan y dulces', true, '2025-12-16 01:06:28.95143+00'),
	('ae6b750a-e878-4cf7-89b0-90adfe449e0c', 'Congelados', 'Helados y comidas congeladas', true, '2025-12-16 01:06:28.95143+00'),
	('823f1ada-e806-4d7e-92f9-54819cb5c901', 'Cuidado Personal', 'Higiene y belleza', true, '2025-12-16 01:06:28.95143+00'),
	('67ce1ca8-a77f-4e0f-8a6d-d0ab4e99ebd5', 'Mascotas', 'Alimento y accesorios para animales', true, '2025-12-16 01:06:28.95143+00'),
	('48e2181a-7d5d-4fc0-a8cc-84e196a79410', 'Medicamentos', 'Fármacos y botiquín', true, '2025-12-16 01:06:28.95143+00'),
	('29e69eb4-fb86-4c80-9b77-d5528ed5d8c7', 'Otros', 'Otros productos varios', true, '2025-12-16 01:06:28.95143+00');


--
-- Data for Name: clientes; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."clientes" ("id", "rut", "nombre", "direccion", "telefono", "cupo_credito", "saldo_actual", "activo", "creado_en", "actualizado_en", "giro", "es_empresa", "comuna") VALUES
	('9107966f-63ce-4d00-82c1-b9706605b43f', '177950031', 'Sebastian Diazz', 'Peumo 21', '+56666778888', 70000.00, 0.00, true, '2025-12-11 01:18:14.167251+00', '2025-12-11 01:18:14.167251+00', NULL, false, NULL),
	('f089d105-e3db-4e90-8832-eb4612519872', '11.111.111-1', 'Juan Perez', 'Calle Falsa 123', '+5699999999', 50000.00, 0.00, true, '2025-12-11 01:31:31.402329+00', '2025-12-11 01:31:31.402329+00', NULL, false, NULL),
	('463502f7-fcd6-40a6-a19f-c49645957637', '22.222.222-2', 'Maria Gonzalez', 'Av. Siempreviva 742', '+5698888888', 100000.00, 0.00, true, '2025-12-11 01:31:31.402329+00', '2025-12-11 01:31:31.402329+00', NULL, false, NULL),
	('2083f912-6d9c-459c-9b75-570c9ebd8f5b', '344323232', 'pepito paga doble', 'villa el porvenir', '948686157333', 0.00, 0.00, true, '2025-12-28 22:37:34.868705+00', '2025-12-28 22:37:34.868705+00', 'Venta de abarrotes', true, NULL),
	('b70d3ea6-cd15-4e1f-a0c4-b26c3405b157', '5235235235', 'Nicol', 'Peumo', '324234234', 70000.00, 1100.00, true, '2025-12-11 01:18:34.806674+00', '2025-12-28 23:05:49.345311+00', NULL, false, NULL);


--
-- Data for Name: configuracion; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."configuracion" ("key", "value") VALUES
	('CODIGO_CAJA', '1234');


--
-- Data for Name: maestro_productos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."maestro_productos" ("id", "nombre", "categoria", "descripcion", "stock_critico", "creado_en", "actualizado_en", "codigo_barra", "precio_venta", "unidad_medida") VALUES
	('b05d2003-fe9f-402b-9d06-40d3e4cda8d1', 'Leche Entera 1L', 'Lacteos', 'Leche caja larga vida', 10, '2025-12-11 01:31:31.402329+00', '2025-12-11 01:31:31.402329+00', '780123456003', 1100.00, 'UN'),
	('f293ca9f-0c62-415a-b4b5-293e0d377111', 'Bebida Cola 3L', 'Bebidas', 'Bebida gaseosa', 10, '2025-12-11 01:31:31.402329+00', '2025-12-11 01:31:31.402329+00', '780123456004', 3200.00, 'UN'),
	('501ef57d-d21a-46b1-8c5e-b69fd70906e6', 'Aceite Vegetal 900ml', 'almacén', 'Aceite maravilla', 5, '2025-12-11 01:31:31.402329+00', '2025-12-11 01:31:31.402329+00', '780123456002', 2500.00, 'UN'),
	('3fb4c8bf-6bee-4232-b850-cd745d0df65a', 'Arroz Grado 2 - 1kg', 'almacén', 'Arroz blanco grano largo', 10, '2025-12-11 01:31:31.402329+00', '2025-12-11 01:31:31.402329+00', '780123456001', 1200.00, 'UN');


--
-- Data for Name: proveedores; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."proveedores" ("id", "nombre", "direccion", "clasificacion", "created_at", "rut", "contacto", "telefono", "email") VALUES
	('0660eb35-c00f-42f1-ab12-98d7c3b6abaa', 'Distribuidora Central', 'Av. Industrial 1000', NULL, '2025-12-11 01:31:31.402329+00', '76.123.456-7', 'Roberto Gomez', '+56911112222', 'contacto@distribuidora.cl');


--
-- Data for Name: ordenes_compra; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."ordenes_compra" ("id", "folio", "proveedor_id", "usuario_id", "estado", "fecha_creacion", "fecha_emision", "fecha_recepcion_final", "total_estimado", "observaciones") VALUES
	('37d1395e-0b91-4fd6-bce0-c2f37adaaaff', 1, '0660eb35-c00f-42f1-ab12-98d7c3b6abaa', 'cfc26a9b-3b50-4b6e-8776-04456334083a', 'COMPLETADA', '2025-12-11 01:43:05.320335+00', NULL, '2025-12-11 01:48:15.334925+00', 39875.00, ''),
	('03d3e6f2-5cc2-48ed-b657-216a27785e07', 2, '0660eb35-c00f-42f1-ab12-98d7c3b6abaa', 'cfc26a9b-3b50-4b6e-8776-04456334083a', 'COMPLETADA', '2025-12-16 00:50:46.550278+00', NULL, '2025-12-16 00:51:24.482021+00', 2.00, ''),
	('e22bc6db-d3ab-403a-8f29-5ddf931f265d', 3, '0660eb35-c00f-42f1-ab12-98d7c3b6abaa', '4f27afce-fb57-408e-af26-52429129554b', 'EMITIDA', '2025-12-19 19:12:17.783101+00', NULL, NULL, 0.00, '');


--
-- Data for Name: detalle_ordenes_compra; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."detalle_ordenes_compra" ("id", "orden_id", "maestro_producto_id", "cantidad_solicitada", "costo_unitario", "cantidad_recibida", "created_at") VALUES
	('fa428d28-dd17-4f37-bc8e-62f6ccc031c7', '37d1395e-0b91-4fd6-bce0-c2f37adaaaff', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', 1, 23343.00, 1, '2025-12-11 01:43:05.580137+00'),
	('8ec10cc8-6255-4329-b559-eb714c6ba55f', '37d1395e-0b91-4fd6-bce0-c2f37adaaaff', 'b05d2003-fe9f-402b-9d06-40d3e4cda8d1', 4, 4133.00, 4, '2025-12-11 01:43:05.580137+00'),
	('04e52e04-7c83-4cb6-be81-a376b718712f', '03d3e6f2-5cc2-48ed-b657-216a27785e07', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', 3, 0.00, 3, '2025-12-16 00:50:46.749022+00'),
	('fd2df461-02ab-4fdc-b970-2eef9cb4c687', '03d3e6f2-5cc2-48ed-b657-216a27785e07', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', 1, 2.00, 1, '2025-12-16 00:50:46.749022+00'),
	('135f96f6-1a0a-439c-ac3a-a1d66a07de9c', 'e22bc6db-d3ab-403a-8f29-5ddf931f265d', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', 9, 0.00, 0, '2025-12-19 19:12:17.962974+00'),
	('2ac2f940-6d77-4eec-ad3b-3746ffb7e18c', 'e22bc6db-d3ab-403a-8f29-5ddf931f265d', 'f293ca9f-0c62-415a-b4b5-293e0d377111', 8, 0.00, 0, '2025-12-19 19:12:17.962974+00');


--
-- Data for Name: recepciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."recepciones" ("id", "numero_documento", "tipo_documento", "proveedor_id", "fecha_recepcion", "usuario_id", "total_neto", "estado", "observaciones") VALUES
	('a2972b64-6d58-4c8a-9a6a-2a64d2515c87', '45666', 'FACTURA', '0660eb35-c00f-42f1-ab12-98d7c3b6abaa', '2025-12-16 00:58:55.264217+00', 'cfc26a9b-3b50-4b6e-8776-04456334083a', 4.00, 'COMPLETADO', NULL),
	('98d480e8-b49c-4fad-9277-92c3478e134d', '234234234', 'FACTURA', '0660eb35-c00f-42f1-ab12-98d7c3b6abaa', '2025-12-28 23:35:37.577443+00', '065bb9e4-5053-43cf-9bed-7f9104c42810', 73389.00, 'COMPLETADO', NULL);


--
-- Data for Name: detalle_recepcion; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."detalle_recepcion" ("id", "recepcion_id", "maestro_producto_id", "cantidad", "precio_costo_unitario", "numero_lote", "fecha_vencimiento", "condicion") VALUES
	('ecc2d29c-41b8-4f9a-a40b-e4a8e3789c41', 'a2972b64-6d58-4c8a-9a6a-2a64d2515c87', 'b05d2003-fe9f-402b-9d06-40d3e4cda8d1', 1.00, 4.00, 'LTT-44', '2025-12-26', 'Bueno'),
	('3ccaf713-716d-4b23-8dc6-bd59699249ef', '98d480e8-b49c-4fad-9277-92c3478e134d', 'b05d2003-fe9f-402b-9d06-40d3e4cda8d1', 10.00, 456.00, 'HYY-345', '2026-01-23', 'Bueno'),
	('5c97cbcd-2982-461c-8af6-9fb0820ca5d1', '98d480e8-b49c-4fad-9277-92c3478e134d', 'f293ca9f-0c62-415a-b4b5-293e0d377111', 21.00, 1349.00, 'BB-3443', '2026-03-28', 'Bueno'),
	('cc49ad21-90b0-437e-90ca-38037c5e46a8', '98d480e8-b49c-4fad-9277-92c3478e134d', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', 45.00, 900.00, 'AC-5539', '2026-03-06', 'Bueno');


--
-- Data for Name: productos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."productos" ("id", "maestro_producto_id", "stock_actual", "numero_lote", "fecha_vencimiento", "condicion", "observaciones", "bloqueado", "fecha_ingreso", "creado_en", "actualizado_en", "proveedor_id", "ubicacion") VALUES
	('151e5151-b1ee-41df-9ca3-0f523387d491', 'b05d2003-fe9f-402b-9d06-40d3e4cda8d1', 0, 'LTT-44', '2025-12-26', 'Bueno', NULL, false, '2025-12-16 00:58:55.264217+00', '2025-12-16 00:58:55.264217+00', '2025-12-16 00:58:55.264217+00', '0660eb35-c00f-42f1-ab12-98d7c3b6abaa', 'Bodega General'),
	('1ec9807f-1152-4925-85ca-fb3acc520e96', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', 0, 'DFSDF', '2025-12-13', 'Bueno', NULL, false, '2025-12-11 01:48:15.334925+00', '2025-12-11 01:48:15.334925+00', '2025-12-11 01:48:15.334925+00', NULL, 'Bodega General'),
	('7b5e2379-514f-4167-9877-d1fb5ba98098', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', 0, 'LOTE-345', '2025-12-20', 'Bueno', NULL, false, '2025-12-16 00:51:24.482021+00', '2025-12-16 00:51:24.482021+00', '2025-12-16 00:51:24.482021+00', NULL, 'Bodega General'),
	('ee9c83fd-07a5-4cd4-b53c-5c6d457553bd', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', 3, 'AC-5539', '2026-03-06', 'Bueno', NULL, false, '2025-12-28 23:35:37.577443+00', '2025-12-28 23:35:37.577443+00', '2025-12-28 23:35:37.577443+00', '0660eb35-c00f-42f1-ab12-98d7c3b6abaa', 'Bodega General'),
	('23a4cf73-66d9-4157-bc2d-008fef9be8d8', 'b05d2003-fe9f-402b-9d06-40d3e4cda8d1', 0, 'SDFSDF', '2025-12-14', 'Bueno', NULL, false, '2025-12-11 01:48:15.334925+00', '2025-12-11 01:48:15.334925+00', '2025-12-11 01:48:15.334925+00', NULL, 'Bodega General'),
	('16e57f83-59f6-4950-9da2-a379acdbdae8', 'f293ca9f-0c62-415a-b4b5-293e0d377111', 3, 'BB-3443', '2026-03-28', 'Bueno', NULL, false, '2025-12-28 23:35:37.577443+00', '2025-12-28 23:35:37.577443+00', '2025-12-28 23:35:37.577443+00', '0660eb35-c00f-42f1-ab12-98d7c3b6abaa', 'Bodega General'),
	('2a619988-197d-47d1-b12c-7d212094a534', 'b05d2003-fe9f-402b-9d06-40d3e4cda8d1', 7, 'HYY-345', '2026-01-23', 'Bueno', NULL, false, '2025-12-28 23:35:37.577443+00', '2025-12-28 23:35:37.577443+00', '2025-12-28 23:35:37.577443+00', '0660eb35-c00f-42f1-ab12-98d7c3b6abaa', 'Bodega General'),
	('32d3a83f-4f94-4222-9c83-ed88ccdb843a', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', 15, 'LOTE-3459', '2025-12-20', 'Bueno', NULL, false, '2025-12-16 00:51:24.482021+00', '2025-12-16 00:51:24.482021+00', '2025-12-16 00:51:24.482021+00', NULL, 'Bodega General');


--
-- Data for Name: ventas; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."ventas" ("id", "fecha_creacion", "usuario_id", "total", "cliente_id", "creado_en", "tipo_venta") VALUES
	('3d6c9372-51f9-4412-ae39-3a68cdb445eb', '2025-12-28 22:24:02.477832+00', '065bb9e4-5053-43cf-9bed-7f9104c42810', 1100.00, NULL, '2025-12-28 22:24:02.477832+00', 'BOLETA'),
	('bd98fbc7-9843-4ab8-9f98-1c26cd814823', '2025-12-28 22:53:55.828507+00', '065bb9e4-5053-43cf-9bed-7f9104c42810', 1100.00, '2083f912-6d9c-459c-9b75-570c9ebd8f5b', '2025-12-28 22:53:55.828507+00', 'FACTURA'),
	('00394a6a-7d76-474e-b869-a623ec45ea79', '2025-12-28 23:05:49.345311+00', '065bb9e4-5053-43cf-9bed-7f9104c42810', 1100.00, 'b70d3ea6-cd15-4e1f-a0c4-b26c3405b157', '2025-12-28 23:05:49.345311+00', 'FIADO'),
	('37198c74-e481-4f4c-a2ed-5d6cd08ac700', '2025-12-28 23:09:55.073773+00', '065bb9e4-5053-43cf-9bed-7f9104c42810', 1100.00, '2083f912-6d9c-459c-9b75-570c9ebd8f5b', '2025-12-28 23:09:55.073773+00', 'FACTURA'),
	('567fb736-c0fc-4114-ae6e-f811ddd9c829', '2025-12-28 23:11:22.835214+00', '065bb9e4-5053-43cf-9bed-7f9104c42810', 1100.00, '2083f912-6d9c-459c-9b75-570c9ebd8f5b', '2025-12-28 23:11:22.835214+00', 'FACTURA'),
	('01eacec8-b1cb-4478-802f-d6315a69bfcc', '2025-12-30 01:53:56.327143+00', '065bb9e4-5053-43cf-9bed-7f9104c42810', 2200.00, NULL, '2025-12-30 01:53:56.327143+00', 'BOLETA'),
	('3a16979e-624a-4966-9db7-fe8e1ad83d15', '2025-12-30 01:56:06.365756+00', '065bb9e4-5053-43cf-9bed-7f9104c42810', 1200.00, '2083f912-6d9c-459c-9b75-570c9ebd8f5b', '2025-12-30 01:56:06.365756+00', 'FACTURA');


--
-- Data for Name: detalle_ventas; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."detalle_ventas" ("id", "venta_id", "producto_id", "cantidad", "precio_unitario", "subtotal", "creado_en", "factor_conversion") VALUES
	('c3d5c07b-1806-4383-8a35-18915d07e0ab', '3d6c9372-51f9-4412-ae39-3a68cdb445eb', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', 1, 1100.00, 1100.00, '2025-12-28 22:24:02.477832+00', 1),
	('57b627dd-1241-4e91-a3a1-6bf91a58f2f1', 'bd98fbc7-9843-4ab8-9f98-1c26cd814823', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', 1, 1100.00, 1100.00, '2025-12-28 22:53:55.828507+00', 1),
	('07300bc0-27d2-49b4-9275-e5a3ef337a71', '00394a6a-7d76-474e-b869-a623ec45ea79', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', 1, 1100.00, 1100.00, '2025-12-28 23:05:49.345311+00', 1),
	('04152a4b-29a7-4e13-ba6f-35d0450cb271', '37198c74-e481-4f4c-a2ed-5d6cd08ac700', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', 1, 1100.00, 1100.00, '2025-12-28 23:09:55.073773+00', 1),
	('5903e648-af18-4c45-90f7-76349ce5d20d', '567fb736-c0fc-4114-ae6e-f811ddd9c829', '151e5151-b1ee-41df-9ca3-0f523387d491', 1, 1100.00, 1100.00, '2025-12-28 23:11:22.835214+00', 1),
	('854a162f-d8db-4434-95b3-8f88202c3355', '01eacec8-b1cb-4478-802f-d6315a69bfcc', '2a619988-197d-47d1-b12c-7d212094a534', 2, 1100.00, 2200.00, '2025-12-30 01:53:56.327143+00', 1),
	('f06a4909-3c89-46d2-9acc-909b0e3204a6', '3a16979e-624a-4966-9db7-fe8e1ad83d15', '32d3a83f-4f94-4222-9c83-ed88ccdb843a', 1, 1200.00, 1200.00, '2025-12-30 01:56:06.365756+00', 1);


--
-- Data for Name: pacientes; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: entregas; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: entregas_items; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: inventory_sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."inventory_sessions" ("id", "nombre", "estado", "observaciones", "creado_por", "fecha_inicio", "fecha_cierre", "creado_en") VALUES
	('c9433fc6-b97d-4b6d-861b-bd000082ba0b', 'Ajuste de prueba', 'REVIEW', NULL, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 21:25:49.822914+00', NULL, '2025-12-28 21:25:49.822914+00'),
	('72efcc29-e3c7-4e11-a7bf-3ea28ddd57b3', 'Pedido', 'REVIEW', NULL, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:43:28.222506+00', NULL, '2025-12-28 23:43:28.222506+00'),
	('964d9007-369b-4c33-a379-9405b1d02e4a', 'Prueba 2', 'REVIEW', NULL, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:48:49.533313+00', NULL, '2025-12-28 23:48:49.533313+00'),
	('e9de9ff2-6133-47c3-8d49-5f6623662f45', 'Prueba 23', 'APPLIED', NULL, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:51:28.743936+00', '2025-12-29 00:01:04.64216+00', '2025-12-28 23:51:28.743936+00');


--
-- Data for Name: inventory_counts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."inventory_counts" ("id", "session_id", "maestro_producto_id", "codigo_escaneado", "cantidad_escaneada", "factor_conversion", "usuario_id", "registrado_en") VALUES
	('e96510a8-714c-48f5-82e3-2f293beea466', 'c9433fc6-b97d-4b6d-861b-bd000082ba0b', 'b05d2003-fe9f-402b-9d06-40d3e4cda8d1', '780123456003', 6, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 21:26:55.477062+00'),
	('efbdc1b3-b8b5-468d-bde6-372fccd5f85f', '72efcc29-e3c7-4e11-a7bf-3ea28ddd57b3', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', '780123456002', 4, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:43:50.460698+00'),
	('bc949c3a-5a40-4d80-a22f-48b85dfcc7ba', '72efcc29-e3c7-4e11-a7bf-3ea28ddd57b3', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', '780123456001', 7, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:44:37.856444+00'),
	('2a779bbb-8878-4678-9f16-93d274afa167', '72efcc29-e3c7-4e11-a7bf-3ea28ddd57b3', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', '780123456001', 3, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:44:46.043021+00'),
	('5d2dee05-e242-4176-988e-f7f7f904ff38', '72efcc29-e3c7-4e11-a7bf-3ea28ddd57b3', 'f293ca9f-0c62-415a-b4b5-293e0d377111', '780123456004', 4, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:44:58.642137+00'),
	('5e493123-11ad-4e8d-9904-acb614a92fc2', '964d9007-369b-4c33-a379-9405b1d02e4a', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', '780123456002', 23, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:49:02.82074+00'),
	('73c4c4af-351f-4c10-8d2e-3dba217721fd', '964d9007-369b-4c33-a379-9405b1d02e4a', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', '780123456001', 5, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:49:26.482279+00'),
	('9ff11a8f-b645-4f03-8bb7-f453a6d5a425', '964d9007-369b-4c33-a379-9405b1d02e4a', 'f293ca9f-0c62-415a-b4b5-293e0d377111', '780123456004', 2, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:49:38.828751+00'),
	('5ed64f51-9f80-4dc5-903c-7b507226c06f', '964d9007-369b-4c33-a379-9405b1d02e4a', 'b05d2003-fe9f-402b-9d06-40d3e4cda8d1', '780123456003', 4, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:49:45.180044+00'),
	('1153b1b9-2076-4eb9-b3aa-48363b37133b', 'e9de9ff2-6133-47c3-8d49-5f6623662f45', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', '780123456002', 3, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:51:35.701028+00'),
	('5b6b0945-1956-4c13-9183-58ab8dcf6a0d', 'e9de9ff2-6133-47c3-8d49-5f6623662f45', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', '780123456001', 4, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:51:53.28076+00'),
	('321640ce-4902-49bf-9b2d-45cbf3fb6682', 'e9de9ff2-6133-47c3-8d49-5f6623662f45', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', '780123456001', 3, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:52:17.835233+00'),
	('04f0c2ee-231e-4b4a-a82b-a8133b222515', 'e9de9ff2-6133-47c3-8d49-5f6623662f45', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', '780123456001', 3, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:53:47.789273+00'),
	('ef810296-17f8-4f3c-8894-2c88334c0bef', 'e9de9ff2-6133-47c3-8d49-5f6623662f45', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', '780123456001', 3, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:54:01.578036+00'),
	('47710037-3f3d-4c4c-805a-7e60632de9ff', 'e9de9ff2-6133-47c3-8d49-5f6623662f45', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', '780123456001', 4, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:54:08.536369+00'),
	('ae9b39a3-ded4-470f-9f9f-114bdeeed109', 'e9de9ff2-6133-47c3-8d49-5f6623662f45', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', '780123456001', -1, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:55:43.950071+00'),
	('3ad0defb-ffec-48cb-812a-ffccc7889193', 'e9de9ff2-6133-47c3-8d49-5f6623662f45', 'b05d2003-fe9f-402b-9d06-40d3e4cda8d1', '780123456003', 1, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:56:01.498714+00'),
	('71dc9217-e68c-4d2b-9912-8aa4e5a5246d', 'e9de9ff2-6133-47c3-8d49-5f6623662f45', 'b05d2003-fe9f-402b-9d06-40d3e4cda8d1', '780123456003', 8, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:56:06.136936+00'),
	('a7a2605f-4ef2-489d-b6cf-9f0844403c1c', 'e9de9ff2-6133-47c3-8d49-5f6623662f45', 'f293ca9f-0c62-415a-b4b5-293e0d377111', '780123456004', 3, 1, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:56:15.206636+00');


--
-- Data for Name: inventory_session_results; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: items_venta; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: movimientos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."movimientos" ("id", "producto_id", "usuario_id", "tipo_movimiento", "cantidad", "motivo", "rut_paciente", "nombre_paciente", "creado_en", "numero_guia", "condicion", "origen_destino") VALUES
	('6c0c5917-c78d-4e0f-a966-df007e7c9607', '1ec9807f-1152-4925-85ca-fb3acc520e96', 'cfc26a9b-3b50-4b6e-8776-04456334083a', 'entrada', 1, 'Recepción Orden Compra', NULL, NULL, '2025-12-11 01:48:15.334925+00', NULL, 'Bueno', 'Proveedor'),
	('0f064203-496e-456d-9584-0c050657445b', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', 'cfc26a9b-3b50-4b6e-8776-04456334083a', 'entrada', 4, 'Recepción Orden Compra', NULL, NULL, '2025-12-11 01:48:15.334925+00', NULL, 'Bueno', 'Proveedor'),
	('2f2fb506-513c-45e7-814e-64c1f8247884', '7b5e2379-514f-4167-9877-d1fb5ba98098', 'cfc26a9b-3b50-4b6e-8776-04456334083a', 'entrada', 3, 'Recepción Orden Compra', NULL, NULL, '2025-12-16 00:51:24.482021+00', NULL, 'Bueno', 'Proveedor'),
	('08b8108d-18d3-49fc-802c-b0c8feb92cda', '32d3a83f-4f94-4222-9c83-ed88ccdb843a', 'cfc26a9b-3b50-4b6e-8776-04456334083a', 'entrada', 1, 'Recepción Orden Compra', NULL, NULL, '2025-12-16 00:51:24.482021+00', NULL, 'Bueno', 'Proveedor'),
	('c97d1ec0-ef57-48d6-a4b8-f31513b6ede1', '151e5151-b1ee-41df-9ca3-0f523387d491', 'cfc26a9b-3b50-4b6e-8776-04456334083a', 'entrada', 1, 'Recepción Compra FACTURA 45666', NULL, NULL, '2025-12-16 00:58:55.264217+00', NULL, 'Bueno', 'Sistema'),
	('d55bc65b-1a6f-42be-8f47-a842fe67d9d1', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', '4f27afce-fb57-408e-af26-52429129554b', 'salida', 2, 'Caja Rota', NULL, NULL, '2025-12-19 18:44:20.050824+00', NULL, 'Bueno', 'Sistema'),
	('947aa78a-514f-4817-91fb-5f900023391d', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', '4f27afce-fb57-408e-af26-52429129554b', 'entrada', 2, 'Caja Rota', NULL, NULL, '2025-12-19 18:44:20.050824+00', NULL, 'Dañado', 'Sistema'),
	('b7113b2d-0403-4407-9a34-750b5bbdf62e', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'VENTA', 1, 'Venta Foli: 3d6c9372-51f9-4412-ae39-3a68cdb445eb', NULL, NULL, '2025-12-28 22:24:02.477832+00', NULL, 'Bueno', 'Sistema'),
	('b4dbccd0-a1f6-4278-b7bd-647f978e04cc', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'VENTA', 1, 'Venta Foli: bd98fbc7-9843-4ab8-9f98-1c26cd814823', NULL, NULL, '2025-12-28 22:53:55.828507+00', NULL, 'Bueno', 'Sistema'),
	('05584342-d500-4f14-81e8-f46f9e09c40f', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'VENTA', 1, 'Venta Foli: 00394a6a-7d76-474e-b869-a623ec45ea79', NULL, NULL, '2025-12-28 23:05:49.345311+00', NULL, 'Bueno', 'Sistema'),
	('54e0be39-94e8-4f0b-9461-c1fecea49fdc', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'VENTA', 1, 'Venta Foli: 37198c74-e481-4f4c-a2ed-5d6cd08ac700', NULL, NULL, '2025-12-28 23:09:55.073773+00', NULL, 'Bueno', 'Sistema'),
	('173e8eff-c26b-4725-9a09-5a3e97c83700', '151e5151-b1ee-41df-9ca3-0f523387d491', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'VENTA', 1, 'Venta Foli: 567fb736-c0fc-4114-ae6e-f811ddd9c829', NULL, NULL, '2025-12-28 23:11:22.835214+00', NULL, 'Bueno', 'Sistema'),
	('92535241-e3ed-4a27-9514-64602151134e', '1ec9807f-1152-4925-85ca-fb3acc520e96', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 1, 'Caja rota
', NULL, NULL, '2025-12-28 23:20:23.354568+00', NULL, 'Bueno', 'Sistema'),
	('4e3a78db-149f-4bcd-8958-0cb05de975e5', '1ec9807f-1152-4925-85ca-fb3acc520e96', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'entrada', 1, 'Caja rota
', NULL, NULL, '2025-12-28 23:20:23.354568+00', NULL, 'Cuarentena', 'Sistema'),
	('6778cba6-93b5-4dd0-9d0a-565d0708012a', '7b5e2379-514f-4167-9877-d1fb5ba98098', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 1, 'w', NULL, NULL, '2025-12-28 23:23:42.310629+00', NULL, 'Bueno', 'Sistema'),
	('f5c26518-3a92-49d6-bcf7-43ebc9fc6ecb', '7b5e2379-514f-4167-9877-d1fb5ba98098', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'entrada', 1, 'w', NULL, NULL, '2025-12-28 23:23:42.310629+00', NULL, 'Dañado', 'Sistema'),
	('51f7c1d7-eece-4f2f-a27e-6c11aaf38acf', '7b5e2379-514f-4167-9877-d1fb5ba98098', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 1, 'w', NULL, NULL, '2025-12-28 23:26:56.409561+00', NULL, 'Bueno', 'Sistema'),
	('3ce35782-64b8-4e7d-b174-1ebe63863cef', '7b5e2379-514f-4167-9877-d1fb5ba98098', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'entrada', 1, 'w', NULL, NULL, '2025-12-28 23:26:56.409561+00', NULL, 'Dañado', 'Sistema'),
	('54c09cea-c294-4585-83e5-e54309aadc30', '1ec9807f-1152-4925-85ca-fb3acc520e96', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 1, '', NULL, NULL, '2025-12-28 23:31:38.058476+00', NULL, 'Cuarentena', 'Sistema'),
	('9e9a318b-a1ac-4397-9a2f-52e1cf9991a3', '1ec9807f-1152-4925-85ca-fb3acc520e96', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'entrada', 1, '', NULL, NULL, '2025-12-28 23:31:38.058476+00', NULL, 'Bueno', 'Sistema'),
	('2951d3bb-de83-427f-af51-efd0422f2bea', '7b5e2379-514f-4167-9877-d1fb5ba98098', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 2, '', NULL, NULL, '2025-12-28 23:31:52.999317+00', NULL, 'Dañado', 'Sistema'),
	('813a0191-3602-445d-9f29-0a94af2b061b', '7b5e2379-514f-4167-9877-d1fb5ba98098', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'entrada', 2, '', NULL, NULL, '2025-12-28 23:31:52.999317+00', NULL, 'Bueno', 'Sistema'),
	('94f1b24d-9c6f-4336-8e5a-a376d02484d7', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 2, '', NULL, NULL, '2025-12-28 23:32:04.863217+00', NULL, 'Dañado', 'Sistema'),
	('0d99f621-5e6d-4463-9821-effadbce1b50', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'entrada', 2, '', NULL, NULL, '2025-12-28 23:32:04.863217+00', NULL, 'Bueno', 'Sistema'),
	('74e9e0b8-68a0-4c8e-b3a4-9d3c8e093492', '2a619988-197d-47d1-b12c-7d212094a534', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'entrada', 10, 'Recepción Compra FACTURA 234234234', NULL, NULL, '2025-12-28 23:35:37.577443+00', NULL, 'Bueno', 'Sistema'),
	('4105be20-1b33-4915-9850-21488b128c44', '16e57f83-59f6-4950-9da2-a379acdbdae8', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'entrada', 21, 'Recepción Compra FACTURA 234234234', NULL, NULL, '2025-12-28 23:35:37.577443+00', NULL, 'Bueno', 'Sistema'),
	('c3be4a5f-39f5-4b87-9ada-111117a19f57', 'ee9c83fd-07a5-4cd4-b53c-5c6d457553bd', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'entrada', 45, 'Recepción Compra FACTURA 234234234', NULL, NULL, '2025-12-28 23:35:37.577443+00', NULL, 'Bueno', 'Sistema'),
	('e631267f-8815-4a97-87ea-bb46417214a9', '1ec9807f-1152-4925-85ca-fb3acc520e96', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 2, 'Ajuste inventario físico (Faltante)', NULL, NULL, '2025-12-29 00:01:04.64216+00', NULL, 'Bueno', 'Sistema'),
	('daad05f1-6b66-4e90-ad13-45f8bda0fecf', '7b5e2379-514f-4167-9877-d1fb5ba98098', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 3, 'Ajuste inventario físico (Faltante)', NULL, NULL, '2025-12-29 00:01:04.64216+00', NULL, 'Bueno', 'Sistema'),
	('5fff8dd5-ae0d-42e7-b053-2e8ad3cd5eff', 'ee9c83fd-07a5-4cd4-b53c-5c6d457553bd', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 42, 'Ajuste inventario físico (Faltante)', NULL, NULL, '2025-12-29 00:01:04.64216+00', NULL, 'Bueno', 'Sistema'),
	('ae3d7aad-85a0-493a-bb39-41d8f335cef5', '23a4cf73-66d9-4157-bc2d-008fef9be8d8', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 2, 'Ajuste inventario físico (Faltante)', NULL, NULL, '2025-12-29 00:01:04.64216+00', NULL, 'Bueno', 'Sistema'),
	('27e660f8-42fb-4c2d-a20a-83941fe38b10', '2a619988-197d-47d1-b12c-7d212094a534', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 1, 'Ajuste inventario físico (Faltante)', NULL, NULL, '2025-12-29 00:01:04.64216+00', NULL, 'Bueno', 'Sistema'),
	('cd2409a6-3cf3-4fe0-952c-fc8ce8e3ffa4', '16e57f83-59f6-4950-9da2-a379acdbdae8', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'salida', 18, 'Ajuste inventario físico (Faltante)', NULL, NULL, '2025-12-29 00:01:04.64216+00', NULL, 'Bueno', 'Sistema'),
	('462b1512-f78d-4c5f-b8f8-61bd3287cf2e', '32d3a83f-4f94-4222-9c83-ed88ccdb843a', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'entrada', 15, 'Ajuste inventario físico (Sobrante)', NULL, NULL, '2025-12-29 00:01:04.64216+00', NULL, 'Bueno', 'Sistema'),
	('2612b86f-1914-4b5e-a6e7-ae1ffcbb1ef2', '2a619988-197d-47d1-b12c-7d212094a534', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'VENTA', 2, 'Venta Foli: 01eacec8-b1cb-4478-802f-d6315a69bfcc', NULL, NULL, '2025-12-30 01:53:56.327143+00', NULL, 'Bueno', 'Sistema'),
	('bbcc8d2a-50ae-4194-926e-e7adbd6e4014', '32d3a83f-4f94-4222-9c83-ed88ccdb843a', '065bb9e4-5053-43cf-9bed-7f9104c42810', 'VENTA', 1, 'Venta Foli: 3a16979e-624a-4966-9db7-fe8e1ad83d15', NULL, NULL, '2025-12-30 01:56:06.365756+00', NULL, 'Bueno', 'Sistema');


--
-- Data for Name: sesiones_caja; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."sesiones_caja" ("id", "usuario_id", "fecha_apertura", "fecha_cierre", "monto_inicial", "monto_final_declarado", "monto_final_esperado", "diferencia", "estado", "observaciones", "caja_id", "nombre_cajera_cierre") VALUES
	('f07383cd-ee19-4cb1-b125-b3ea9ff64d8b', 'cfc26a9b-3b50-4b6e-8776-04456334083a', '2025-12-11 01:21:56.771988+00', '2025-12-15 23:43:56.866659+00', 45000.00, 150000.00, 45000.00, 105000.00, 'CERRADA', NULL, NULL, NULL),
	('a13fb0a7-700a-47df-9258-75d563355d55', 'cfc26a9b-3b50-4b6e-8776-04456334083a', '2025-12-15 23:55:22.678778+00', '2025-12-15 23:55:34.516063+00', 34455.00, 35000.00, 34455.00, 545.00, 'CERRADA', NULL, NULL, NULL),
	('3e014102-fff1-46ad-8563-a82eb187edc0', 'cfc26a9b-3b50-4b6e-8776-04456334083a', '2025-12-16 00:02:36.344842+00', '2025-12-16 00:17:20.430012+00', 30000.00, 5.00, 30000.00, -29995.00, 'CERRADA', NULL, '70d6fb81-58f9-4d6b-b4e1-ab13f02ee360', 'Sdiaz'),
	('1861705c-873a-475d-9059-711b352a13ad', 'cfc26a9b-3b50-4b6e-8776-04456334083a', '2025-12-16 00:17:39.211079+00', '2025-12-16 00:18:54.544109+00', 10000.00, 5.00, 10000.00, -9995.00, 'CERRADA', NULL, '70d6fb81-58f9-4d6b-b4e1-ab13f02ee360', 'Sdiaz'),
	('be016221-6211-4e5e-b7d7-e66044dd0f21', 'cfc26a9b-3b50-4b6e-8776-04456334083a', '2025-12-16 01:30:25.643547+00', '2025-12-16 01:38:58.893989+00', 50000.00, 67999.00, 50000.00, 17999.00, 'CERRADA', NULL, '70d6fb81-58f9-4d6b-b4e1-ab13f02ee360', 'Seba'),
	('4e716cc5-ed98-4de3-a3ea-d680c25cde34', 'cfc26a9b-3b50-4b6e-8776-04456334083a', '2025-12-16 01:39:13.795906+00', '2025-12-16 14:00:53.776546+00', 33333.00, 330000.00, 33333.00, 296667.00, 'CERRADA', NULL, '70d6fb81-58f9-4d6b-b4e1-ab13f02ee360', 'Sebas'),
	('c34cf2d1-815a-40e4-b9b9-705fc4b18c65', 'cfc26a9b-3b50-4b6e-8776-04456334083a', '2025-12-16 14:03:01.417899+00', '2025-12-28 22:06:35.878812+00', 20000.00, 0.00, 0.00, 0.00, 'CERRADA', NULL, '70d6fb81-58f9-4d6b-b4e1-ab13f02ee360', 'CIERRE ADMINISTRATIVO FORZADO'),
	('fd08e1e2-119c-4eee-a84c-acbf43443093', '4f27afce-fb57-408e-af26-52429129554b', '2025-12-19 18:54:18.021421+00', '2025-12-28 22:06:35.878812+00', 24999.00, 0.00, 0.00, 0.00, 'CERRADA', NULL, 'c6f98490-7ef0-4fe9-9e3a-976e085aa804', 'CIERRE ADMINISTRATIVO FORZADO'),
	('b50caf56-7183-4425-bf99-e79fcf266e46', '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 22:14:13.285761+00', '2025-12-28 23:18:54.879209+00', 20000.00, 20000.00, 20000.00, 0.00, 'CERRADA', NULL, '70d6fb81-58f9-4d6b-b4e1-ab13f02ee360', 'Marin'),
	('df52a3ed-fb7b-4d42-a072-c0be088d9414', '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-30 01:53:35.066375+00', NULL, 334.00, NULL, NULL, NULL, 'ABIERTA', NULL, '70d6fb81-58f9-4d6b-b4e1-ab13f02ee360', NULL),
	('31e5dcaf-014c-4375-8acc-addfe6c9f799', 'aae75c27-6f6a-4ef5-a622-239226b1e8f9', '2026-01-06 01:46:23.711226+00', NULL, 23444.00, NULL, NULL, NULL, 'ABIERTA', NULL, 'c6f98490-7ef0-4fe9-9e3a-976e085aa804', NULL);


--
-- Data for Name: movimientos_caja; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."movimientos_caja" ("id", "sesion_id", "tipo_movimiento", "monto", "descripcion", "referencia_id", "created_at") VALUES
	('3327edaf-dfc8-4341-bd81-7b84bec6b9a4', 'f07383cd-ee19-4cb1-b125-b3ea9ff64d8b', 'APERTURA', 45000.00, 'Monto Inicial de Caja', NULL, '2025-12-11 01:21:56.771988+00'),
	('b33142b7-adbc-403b-b68b-1d736d0fdc51', 'a13fb0a7-700a-47df-9258-75d563355d55', 'APERTURA', 34455.00, 'Monto Inicial de Caja', NULL, '2025-12-15 23:55:22.678778+00'),
	('762a25dd-5c8e-4ecf-b458-6dd5e8e25622', '3e014102-fff1-46ad-8563-a82eb187edc0', 'APERTURA', 30000.00, 'Monto Inicial de Caja', NULL, '2025-12-16 00:02:36.344842+00'),
	('55095e01-b1b4-43bf-ab3f-a58ab277335f', '1861705c-873a-475d-9059-711b352a13ad', 'APERTURA', 10000.00, 'Monto Inicial de Caja', NULL, '2025-12-16 00:17:39.211079+00'),
	('d9df4927-0a78-48d6-bcb1-999975e0224f', 'be016221-6211-4e5e-b7d7-e66044dd0f21', 'APERTURA', 50000.00, 'Monto Inicial de Caja', NULL, '2025-12-16 01:30:25.643547+00'),
	('7aa042a2-ff98-433e-9489-056d7eba2f15', '4e716cc5-ed98-4de3-a3ea-d680c25cde34', 'APERTURA', 33333.00, 'Monto Inicial de Caja', NULL, '2025-12-16 01:39:13.795906+00'),
	('80f15650-5311-4db6-aa0d-adfc04c3a7b2', 'c34cf2d1-815a-40e4-b9b9-705fc4b18c65', 'APERTURA', 20000.00, 'Monto Inicial de Caja', NULL, '2025-12-16 14:03:01.417899+00'),
	('e248e176-06d8-4247-ac7c-f38c6b57d45d', 'fd08e1e2-119c-4eee-a84c-acbf43443093', 'APERTURA', 24999.00, 'Monto Inicial de Caja', NULL, '2025-12-19 18:54:18.021421+00'),
	('d0ebbe51-fbb8-4e35-920d-d94a26472719', 'b50caf56-7183-4425-bf99-e79fcf266e46', 'APERTURA', 20000.00, 'Monto Inicial de Caja', NULL, '2025-12-28 22:14:13.285761+00'),
	('a96ef767-4497-44ad-905e-b2a7e3598867', 'df52a3ed-fb7b-4d42-a072-c0be088d9414', 'APERTURA', 334.00, 'Monto Inicial de Caja', NULL, '2025-12-30 01:53:35.066375+00'),
	('954a0f62-af3b-4191-b0d0-620f83f59536', '31e5dcaf-014c-4375-8acc-addfe6c9f799', 'APERTURA', 23444.00, 'Monto Inicial de Caja', NULL, '2026-01-06 01:46:23.711226+00');


--
-- Data for Name: movimientos_cuenta_corriente; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."movimientos_cuenta_corriente" ("id", "cliente_id", "venta_id", "fecha", "tipo", "monto", "saldo_posterior", "descripcion", "usuario_id", "creado_en") VALUES
	('d8823121-3ec9-4c39-bbf3-254f1a6d550d', 'b70d3ea6-cd15-4e1f-a0c4-b26c3405b157', '00394a6a-7d76-474e-b869-a623ec45ea79', '2025-12-28 23:05:49.345311+00', 'COMPRA', 1100.00, 1100.00, NULL, '065bb9e4-5053-43cf-9bed-7f9104c42810', '2025-12-28 23:05:49.345311+00');


--
-- Data for Name: movimientos_stock; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."movimientos_stock" ("id", "fecha_creacion", "producto_id", "usuario_id", "cantidad", "tipo", "nota") VALUES
	('a877875a-de87-46a4-aa51-724375aa164e', '2025-11-04 01:26:50.395817+00', '20f14854-fdd1-43d6-8866-202ce2bd5004', '448cc15a-b364-443b-b347-6adb4d8229a1', 3, 'ingreso_manual', 'Pedido 21');


--
-- Data for Name: producto_presentaciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."producto_presentaciones" ("id", "maestro_producto_id", "codigo_barra", "nombre_presentacion", "factor_conversion", "costo_referencial", "precio_venta", "creado_en") VALUES
	('d9f201a3-057e-4b8b-a296-90e6257b0bd8', '501ef57d-d21a-46b1-8c5e-b69fd70906e6', '33888488', 'Caja Aceite Vegetal 900ml', 12, NULL, NULL, '2025-12-28 21:13:44.618748+00'),
	('daf208a0-761a-4a8a-b75e-0a93f76a6073', '3fb4c8bf-6bee-4232-b850-cd745d0df65a', '7801234560054645', 'Caja Arroz Grado 2 ', 24, NULL, NULL, '2025-12-28 21:14:37.029603+00');


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--

INSERT INTO "storage"."buckets" ("id", "name", "owner", "created_at", "updated_at", "public", "avif_autodetection", "file_size_limit", "allowed_mime_types", "owner_id", "type") VALUES
	('checklist-evidence', 'checklist-evidence', NULL, '2025-12-11 00:27:41.964395+00', '2025-12-11 00:27:41.964395+00', true, false, NULL, NULL, NULL, 'STANDARD');


--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: prefixes; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: supabase_auth_admin
--

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 21, true);


--
-- Name: ordenes_compra_folio_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."ordenes_compra_folio_seq"', 3, true);


--
-- PostgreSQL database dump complete
--


RESET ALL;
