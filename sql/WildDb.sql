--
-- PostgreSQL database dump
--

-- Dumped from database version 12.2
-- Dumped by pg_dump version 12.2

-- Started on 2020-05-31 15:37:54

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 210 (class 1255 OID 32808)
-- Name: addlogrecord(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addlogrecord(text character varying) RETURNS oid
    LANGUAGE plpgsql
    AS $$
DECLARE myid oid;
BEGIN
INSERT INTO public."Log"(
	 "Action", "TimeStamp")
	VALUES (text, clock_timestamp()) RETURNING "Id" INTO myid;
Return myid; 
END
$$;


ALTER FUNCTION public.addlogrecord(text character varying) OWNER TO postgres;

--
-- TOC entry 211 (class 1255 OID 32867)
-- Name: addrequest(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addrequest(text character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE myid bigint;
BEGIN
INSERT INTO public."Requests"(
	 "Message", "CreateDate")
	VALUES (text, clock_timestamp()) RETURNING "Id" INTO myid;
Return myid; 
END
$$;


ALTER FUNCTION public.addrequest(text character varying) OWNER TO postgres;

--
-- TOC entry 225 (class 1255 OID 40980)
-- Name: addrequestinqueue(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addrequestinqueue() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE ManagerId bigint;
BEGIN
	SELECT "Id" INTO ManagerId FROM public."Managers"
	WHERE COALESCE(array_length("Queue", 1), 0) < 2	
	ORDER BY COALESCE(array_length("Queue", 1), 0) ASC
	LIMIT 1 ;
	
	IF ManagerId > 0  
	THEN
	INSERT INTO public."RequestQueue"("Request_Id","Status","Manager_Id","ValidTime") VALUES
	(New."Id", 1, ManagerId, (CURRENT_TIMESTAMP + (15 * interval '1 minute')));
	
	UPDATE public."Managers"
	SET  "Queue"= "Queue" || ARRAY[new."Id"]
	WHERE "Id" = ManagerId;
	
	ELSE
		INSERT INTO public."RequestQueue"("Request_Id","Status")VALUES
	(New."Id",0);
	END IF;

	
	RETURN new;
END;
$$;


ALTER FUNCTION public.addrequestinqueue() OWNER TO postgres;

--
-- TOC entry 226 (class 1255 OID 49171)
-- Name: array_diff(anyarray, anyarray); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.array_diff(array1 anyarray, array2 anyarray) RETURNS anyarray
    LANGUAGE sql IMMUTABLE
    AS $$
    select coalesce(array_agg(elem), '{}')
    from unnest(array1) elem
    where elem <> all(array2)
$$;


ALTER FUNCTION public.array_diff(array1 anyarray, array2 anyarray) OWNER TO postgres;

--
-- TOC entry 227 (class 1255 OID 49170)
-- Name: querymanagement(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.querymanagement() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE doneids bigint[];
DECLARE lateids bigint[];
DECLARE ids bigint[];
DECLARE ManagerId bigint;
DECLARE m bigint[];
BEGIN
	--массив отработанных id
	doneids := ARRAY(
	SELECT "Request_Id" FROM public."RequestQueue"
	WHERE "Status" = 3
	);
	--массив просроченых Id
	lateids := ARRAY(
	SELECT "Request_Id" FROM public."RequestQueue"
	WHERE ("Status" = 1) and ("ValidTime" < CURRENT_TIME)
	);
	
	--удаляем обработанные Id из массивов менеджеров
	
	UPDATE public."Managers"
	SET  "Queue" = (SELECT array_diff("Queue", doneids));
	
	--удаляем обработанные Id из массивов менеджеров
	UPDATE public."Managers"
	SET  "Queue" = (SELECT array_diff("Queue", lateids));
	
	--удаляем отработанные заявки из очереди
	DELETE FROM public."RequestQueue"
	WHERE array_position(doneids, "Request_Id") IS NOT NULL;
	
	--получаем массив Id которые висят на менеджере больше 15 минут или ожидают
	ids := ARRAY(SELECT "Request_Id" FROM public."RequestQueue"
	WHERE ("Status" = 1 and "ValidTime" < CURRENT_TIME) OR ("Status" = 0));
	
  FOREACH m SLICE 1 IN ARRAY ids
  LOOP
  	SELECT "Id" INTO ManagerId FROM public."Managers"
	WHERE COALESCE(array_length("Queue", 1), 0) < 2	
	ORDER BY COALESCE(array_length("Queue", 1), 0) ASC
	LIMIT 1 ;
	
	IF ManagerId > 0  
	THEN
	UPDATE public."RequestQueue"
	SET "Request_Id" = m[1],
	"Status" = 1,
	"ValidTime" = (CURRENT_TIME + (15 * interval '1 minute')) 
	WHERE "Manager_Id" = ManagerId;
	
	UPDATE public."Managers"
	SET  "Queue"= "Queue" || ARRAY[m[1]]
	WHERE "Id" = ManagerId;
	
	ELSE
		UPDATE  public."RequestQueue"
		SET "Request_Id" = m[1],
		"Status" = 0,
		"ValidTime" = nil;
	END IF;
  END LOOP;
	
	
	
	
return 0;
END
$$;


ALTER FUNCTION public.querymanagement() OWNER TO postgres;

--
-- TOC entry 224 (class 1255 OID 32892)
-- Name: removerequest(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.removerequest(reqid bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
	DECLARE myid bigint;
	DECLARE reqstatus integer;
BEGIN
	SELECT "Status" INTO reqstatus FROM public."RequestQueue" 
	WHERE "Request_Id" = ReqId;

	IF (reqstatus = 0) or (reqstatus = 1)  THEN
		DELETE FROM public."RequestQueue" 
		WHERE "Request_Id" = ReqId;
		Return 0; 
	END IF;
	
	Return 1;
	
END
$$;


ALTER FUNCTION public.removerequest(reqid bigint) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 202 (class 1259 OID 32809)
-- Name: Log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Log" (
    "Id" bigint NOT NULL,
    "Action" character varying,
    "TimeStamp" time without time zone
);


ALTER TABLE public."Log" OWNER TO postgres;

--
-- TOC entry 205 (class 1259 OID 32878)
-- Name: Log_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."Log" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."Log_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 10000000000
    CACHE 1
);


--
-- TOC entry 208 (class 1259 OID 32893)
-- Name: Managers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Managers" (
    "Id" bigint NOT NULL,
    "Queue" bigint[],
    "Name" character varying(64) NOT NULL
);


ALTER TABLE public."Managers" OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 32902)
-- Name: Managers_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."Managers" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."Managers_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 132123123
    CACHE 1
);


--
-- TOC entry 203 (class 1259 OID 32818)
-- Name: RequestQueue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."RequestQueue" (
    "Id" bigint NOT NULL,
    "Request_Id" bigint NOT NULL,
    "Status" integer NOT NULL,
    "Manager_Id" oid,
    "ValidTime" time with time zone
);


ALTER TABLE public."RequestQueue" OWNER TO postgres;

--
-- TOC entry 204 (class 1259 OID 32865)
-- Name: RequestQueue_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."RequestQueue" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."RequestQueue_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 206 (class 1259 OID 32880)
-- Name: Requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Requests" (
    "Id" bigint NOT NULL,
    "Message" character varying(1024) NOT NULL,
    "CreateDate" timestamp without time zone NOT NULL
);


ALTER TABLE public."Requests" OWNER TO postgres;

--
-- TOC entry 207 (class 1259 OID 32887)
-- Name: Requests_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."Requests" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."Requests_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 123123123
    CACHE 1
);


--
-- TOC entry 2847 (class 0 OID 32809)
-- Dependencies: 202
-- Data for Name: Log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Log" ("Id", "Action", "TimeStamp") FROM stdin;
11	test	22:11:50.301544
13	request added. Id: \f	22:12:05.480161
15	request added. Id: 	22:18:14.615519
17	request added. Id: 16	22:21:14.669064
19	request added. Id: 0	17:12:59.403578
21	request added. Id: 0	17:15:26.368258
23	request added. Id: 0	17:15:28.793456
25	request added. Id: 0	17:17:59.344539
27	request added. Id: 0	17:20:31.930653
1	request added. Id: 9	18:15:19.882989
2	request added. Id: 10	20:55:44.144597
3	request added. Id: 11	21:02:25.908108
4	request added. Id: 12	21:04:18.728816
5	request added. Id: 13	21:04:55.497116
6	request added. Id: 14	19:59:23.198445
7	Request cacel try: Request 14 successfully canceled	19:59:23.251576
8	request added. Id: 15	20:00:03.529569
9	request added. Id: 16	20:01:58.379324
10	request added. Id: 17	20:24:44.029307
12	request added. Id: 0	20:26:31.080794
14	request added. Id: 0	20:51:21.363155
16	request added. Id: 23	21:15:16.713718
18	request added. Id: 25	21:17:06.678167
20	request added. Id: 27	12:44:12.82593
22	request added. Id: 29	12:46:34.454794
24	request added. Id: 31	12:47:02.216493
26	request added. Id: 33	12:47:26.16747
28	request added. Id: 35	14:18:10.762117
29	request added. Id: 36	14:18:13.890973
30	request added. Id: 37	14:18:15.88562
31	request added. Id: 38	14:18:17.805676
32	request added. Id: 39	14:18:19.297913
33	request added. Id: 40	14:18:21.852342
\.


--
-- TOC entry 2853 (class 0 OID 32893)
-- Dependencies: 208
-- Data for Name: Managers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Managers" ("Id", "Queue", "Name") FROM stdin;
1	{35,38}	Данька
3	{36,39}	Мишаня
2	{37,40}	Мельник
\.


--
-- TOC entry 2848 (class 0 OID 32818)
-- Dependencies: 203
-- Data for Name: RequestQueue; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."RequestQueue" ("Id", "Request_Id", "Status", "Manager_Id", "ValidTime") FROM stdin;
37	35	1	1	14:33:10.761475+03
38	36	1	3	14:33:13.881849+03
39	37	1	2	14:33:15.884345+03
40	38	1	1	14:33:17.804403+03
41	39	1	3	14:33:19.297197+03
42	40	0	\N	\N
43	40	1	2	14:44:14.827127+03
\.


--
-- TOC entry 2851 (class 0 OID 32880)
-- Dependencies: 206
-- Data for Name: Requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Requests" ("Id", "Message", "CreateDate") FROM stdin;
27	Test api 1	2020-05-31 12:44:12.784777
28	Test api 1	2020-05-31 12:46:20.857607
29	Test api 1	2020-05-31 12:46:34.453656
30	Test api 1	2020-05-31 12:46:51.303423
31	Test api 1	2020-05-31 12:47:02.194581
32	Test api 1	2020-05-31 12:47:04.040357
33	Test api 1	2020-05-31 12:47:26.166173
34	Test api 1	2020-05-31 14:18:07.217552
35	Test api 1	2020-05-31 14:18:10.761526
36	Test api 1	2020-05-31 14:18:13.881915
37	Test api 1	2020-05-31 14:18:15.884393
38	Test api 1	2020-05-31 14:18:17.804452
39	Test api 1	2020-05-31 14:18:19.297245
40	Test api 1	2020-05-31 14:18:21.851178
\.


--
-- TOC entry 2860 (class 0 OID 0)
-- Dependencies: 205
-- Name: Log_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Log_Id_seq"', 33, true);


--
-- TOC entry 2861 (class 0 OID 0)
-- Dependencies: 209
-- Name: Managers_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Managers_Id_seq"', 3, true);


--
-- TOC entry 2862 (class 0 OID 0)
-- Dependencies: 204
-- Name: RequestQueue_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."RequestQueue_Id_seq"', 43, true);


--
-- TOC entry 2863 (class 0 OID 0)
-- Dependencies: 207
-- Name: Requests_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Requests_Id_seq"', 40, true);


--
-- TOC entry 2717 (class 2606 OID 32860)
-- Name: RequestQueue  RequestQueue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."RequestQueue"
    ADD CONSTRAINT " RequestQueue_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 2715 (class 2606 OID 32870)
-- Name: Log Pk_Log; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Log"
    ADD CONSTRAINT "Pk_Log" PRIMARY KEY ("Id");


--
-- TOC entry 2719 (class 2606 OID 32900)
-- Name: Managers Pk_managers; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Managers"
    ADD CONSTRAINT "Pk_managers" PRIMARY KEY ("Id");


--
-- TOC entry 2720 (class 2620 OID 40981)
-- Name: Requests queue_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER queue_insert AFTER INSERT ON public."Requests" FOR EACH ROW EXECUTE FUNCTION public.addrequestinqueue();


-- Completed on 2020-05-31 15:37:54

--
-- PostgreSQL database dump complete
--

