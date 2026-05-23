DO $$
DECLARE
    v_empresa UUID;
    v_bodega_gral UUID;
BEGIN
    SELECT id INTO v_empresa FROM public.empresas ORDER BY created_at ASC LIMIT 1;
    SELECT id INTO v_bodega_gral FROM public.bodegas WHERE tipo = 'general' AND empresa_id = v_empresa ORDER BY created_at ASC LIMIT 1;

    INSERT INTO public.proveedores (nombre, rut, direccion, clasificacion, contacto, telefono, email, empresa_id)
    SELECT t.nombre, t.rut, t.direccion, t.clasificacion, t.contacto, t.telefono, t.email, v_empresa
    FROM (VALUES
        ('CCU Chile S.A.','96556990-5','Av. Las Condes 11200, Santiago','Bebidas','Pedidos CCU','+56225606000','ventas@ccu.cl'),
        ('Coca-Cola Embonor S.A.','96680260-2','Av. Presidente Riesco 5711, Las Condes','Bebidas','Area Ventas','+56225999999','contacto@embonor.cl'),
        ('Colun Ltda.','81785400-6','Ruta 5 Sur Km 965, La Union','Lacteos','Ventas Nacional','+56642320000','colun@colun.cl'),
        ('Carozzi S.A.','91435000-3','Camino Longitudinal 5201, Nos','Abarrotes','Fuerza Ventas','+56225435000','clientes@carozzi.cl'),
        ('Nestle Chile S.A.','91257000-7','Av. Nueva Tajamar 481, Las Condes','Abarrotes','Servicio Cliente','+56227794000','chile@nestle.com'),
        ('Pepsico Chile S.A.','79908960-9','Av. Del Valle 745, Huechuraba','Snacks','Trade Marketing','+56224441000','info@pepsico.cl'),
        ('Unilever Chile S.A.','91558000-8','Av. Vitacura 2939, Las Condes','Limpieza','Key Account','+56226561600','chile@unilever.com'),
        ('Procter & Gamble Chile','96836610-K','Cerro El Plomo 5680, Las Condes','Cuidado Personal','Ventas Masivas','+56226567400','consumo@pg.com'),
        ('San Jorge S.A.','83721000-9','Av. Gladys Marin 5530, Estacion Central','Fiambreria','Pedidos San Jorge','+56227766000','ventas@sanjorge.cl'),
        ('British American Tobacco','99568000-4','Av. Apoquindo 4501, Las Condes','Cigarrillos','Canal Tradicional','+56224955200','chile@bat.com')
    ) AS t(nombre, rut, direccion, clasificacion, contacto, telefono, email)
    WHERE NOT EXISTS (SELECT 1 FROM public.proveedores WHERE nombre = t.nombre);

    INSERT INTO public.categorias (nombre, descripcion, empresa_id)
    SELECT t.nombre, t.descripcion, v_empresa
    FROM (VALUES
        ('Bebidas','Jugos, gaseosas, aguas, energeticas'),
        ('Lacteos','Leche, yogurt, queso, mantequilla'),
        ('Abarrotes','Arroz, fideos, aceite, conservas'),
        ('Snacks','Papas fritas, galletas, chocolates, frutos secos'),
        ('Limpieza','Detergentes, cloro, desinfectantes, papel'),
        ('Cuidado Personal','Shampoo, jabon, cremas, desodorante'),
        ('Panaderia','Pan, hallullas, marraqueta, masas'),
        ('Fiambreria','Jamon, queso laminado, salame, mortadela'),
        ('Congelados','Helados, verduras congeladas, nuggets'),
        ('Cigarrillos','Cigarros, tabaco, encendedores')
    ) AS t(nombre, descripcion)
    WHERE NOT EXISTS (SELECT 1 FROM public.categorias WHERE nombre = t.nombre AND empresa_id = v_empresa);

    INSERT INTO public.maestro_productos (nombre, categoria, codigo_barra, precio_venta, unidad_medida, stock_critico, controla_stock, activo, empresa_id)
    SELECT t.nombre, t.categoria, t.codigo_barra, t.precio_venta, 'UN', t.stock_critico, true, true, v_empresa
    FROM (VALUES
        ('Coca-Cola Original 500cc','Bebidas','7801620800877',1200,24),
        ('Coca-Cola Zero 500cc','Bebidas','7801620800907',1200,24),
        ('Coca-Cola Original 1.5L','Bebidas','7801620800112',2000,12),
        ('Coca-Cola Original 3L','Bebidas','7801620800150',3100,8),
        ('Sprite 500cc','Bebidas','7801620800884',1100,24),
        ('Fanta Naranja 500cc','Bebidas','7801620800891',1100,24),
        ('Inca Kola 500cc','Bebidas','7750182000426',1200,12),
        ('Agua Mineral Cachantun c/gas 500cc','Bebidas','7802000001235',800,24),
        ('Agua Mineral Cachantun s/gas 1.5L','Bebidas','7802000001242',1100,12),
        ('Gatorade Cool Blue 500cc','Bebidas','7801620800921',1300,12),
        ('Bilz 500cc','Bebidas','7801620801454',1000,24),
        ('Pap 500cc','Bebidas','7801620801461',1000,24),
        ('Monster Energy Original 473cc','Bebidas','070847021452',1800,12),
        ('Red Bull 250cc','Bebidas','9002490100070',1900,12),
        ('Jugo Watts Naranja 1L','Bebidas','7802605010010',1400,8),
        ('Leche Entera Colun 1L','Lacteos','7801200001007',1100,24),
        ('Leche Semidescremada Colun 1L','Lacteos','7801200001014',1100,24),
        ('Leche Descremada Colun 1L','Lacteos','7801200001021',1150,16),
        ('Yogurt Protein+ Colun Frutilla 200g','Lacteos','7801200002001',900,20),
        ('Yogurt Batido Colun Damasco 1L','Lacteos','7801200002018',1500,8),
        ('Queso Gauda Colun Laminado 200g','Lacteos','7801200003008',2800,6),
        ('Queso Fresco Colun 300g','Lacteos','7801200003015',2200,6),
        ('Mantequilla Colun c/sal 250g','Lacteos','7801200004005',3200,6),
        ('Margarina Colun 250g','Lacteos','7801200004012',1800,6),
        ('Crema Nestle 200cc','Lacteos','7801150001001',1500,12),
        ('Manjar Colun 500g','Lacteos','7801200005002',2500,8),
        ('Quesillo Colun 350g','Lacteos','7801200003022',1600,8),
        ('Leche sin Lactosa Colun 1L','Lacteos','7801200001038',1400,12),
        ('Arroz Grado 1 Carozzi 1kg','Abarrotes','7801850100200',1800,20),
        ('Fideos Spaghetti Carozzi 400g','Abarrotes','7801850200100',900,30),
        ('Fideos Corbatitas Carozzi 400g','Abarrotes','7801850200117',900,30),
        ('Fideos Tallarines 77 Carozzi 400g','Abarrotes','7801850200209',850,30),
        ('Aceite Vegetal Chef 1L','Abarrotes','7801850300307',2200,16),
        ('Aceite Maravilla Chef 1L','Abarrotes','7801850300314',2300,16),
        ('Aceite Oliva O-live 250cc','Abarrotes','7801850300321',3500,8),
        ('Sal de Mesa Lobos 1kg','Abarrotes','7801000001001',700,20),
        ('Azucar Blanca Iansa 1kg','Abarrotes','7801100001001',1200,16),
        ('Harina Selecta 1kg','Abarrotes','7801850301007',1000,20),
        ('Tomate Conserva Carozzi 440g','Abarrotes','7801850302004',1000,24),
        ('Jurel Natural Angelmo 425g','Abarrotes','7801975000010',1500,12),
        ('Atun Lomitos Agua Angelmo 170g','Abarrotes','7801975000027',1800,16),
        ('Mayonesa Hellmanns 250cc','Abarrotes','7801150002008',2200,12),
        ('Salsa Tomates Carozzi 200g','Abarrotes','7801850303001',800,24),
        ('Ketchup Carozzi 200g','Abarrotes','7801850304008',800,24),
        ('Mermelada Frugo Frambuesa 400g','Abarrotes','7801850305005',1500,12),
        ('Te Supremo Ceylan 100un','Abarrotes','7801120001001',2500,8),
        ('Cafe Nescafe Clasico 170g','Abarrotes','7801150003005',4500,6),
        ('Sopa Nestle Gallina 72g','Abarrotes','7801150004002',700,32),
        ('Papas Fritas Lays Clasicas 130g','Snacks','7802002001001',2000,16),
        ('Papas Fritas Lays Onduladas 130g','Snacks','7802002001002',2000,16),
        ('Papas Fritas Marco Polo 100g','Snacks','7802605001010',1000,20),
        ('Doritos Nacho Cheese 140g','Snacks','7802002002008',2100,12),
        ('Cheetos Queso 100g','Snacks','7802002003005',1500,16),
        ('Ramitas Krachitos Queso 100g','Snacks','7802002004002',1000,20),
        ('Manhattan Salado 140g','Snacks','7802002005009',900,24),
        ('Galleta Triton Chocolate 120g','Snacks','7801850400102',1500,12),
        ('Galleta Frac Chocolate 120g','Snacks','7801850400201',1500,12),
        ('Galleta Carioca Chocolate 120g','Snacks','7801850400300',1200,12),
        ('Galleta Oblea Coco 100g','Snacks','7801850400409',800,24),
        ('Galleta Morocha Vainilla 140g','Snacks','7801850400508',1000,16),
        ('Chocolate Sahne-Nuss 50g','Snacks','7801150005009',1200,20),
        ('Chocolate Super 8 50g','Snacks','7801150006006',1000,20),
        ('Chocolate Rolls 45g','Snacks','7801150007003',500,24),
        ('Cabritas Microondas 90g','Snacks','7802002006006',1200,12),
        ('Detergente Liquido Omo 750cc','Limpieza','7801151001005',3200,8),
        ('Detergente Polvo Omo 1kg','Limpieza','7801151002002',3500,8),
        ('Cloro Clorinda Original 1L','Limpieza','7801151003009',1200,12),
        ('Limpiapisos Oso 750cc','Limpieza','7801151004006',1800,8),
        ('Lavaloza Quix 500cc','Limpieza','7801151005003',1500,12),
        ('Lava Loza Patito 500cc','Limpieza','7801151006000',1000,12),
        ('Desinfectante Lysoform Aerosol 360cc','Limpieza','7801151007007',2500,8),
        ('Papel Higienico Elite Doble Hoja 24un','Limpieza','7801151008004',5500,6),
        ('Papel Higienico Nova 4un','Limpieza','7801151009001',1200,24),
        ('Servilletas Elite 100un','Limpieza','7801151010006',1500,12),
        ('Toalla Nova 1un','Limpieza','7801151011003',800,24),
        ('Shampoo Head Shoulders 375cc','Cuidado Personal','7801152001004',4500,6),
        ('Shampoo Pantene 375cc','Cuidado Personal','7801152002001',4200,6),
        ('Shampoo Ballerina Manzanilla 350cc','Cuidado Personal','7801152003008',2000,12),
        ('Desodorante Rexona Clinical Roll 50cc','Cuidado Personal','7801152004005',3500,8),
        ('Desodorante Dove Aerosol 150cc','Cuidado Personal','7801152005002',3200,8),
        ('Jabon Liquido Dove 250cc','Cuidado Personal','7801152006009',2800,8),
        ('Jabon Barra Protex 120g','Cuidado Personal','7801152007006',1000,24),
        ('Pasta Dental Colgate Triple 100g','Cuidado Personal','7801152008003',2500,12),
        ('Cepillo Dientes Colgate Classic','Cuidado Personal','7801152009000',1500,16),
        ('Crema Corporal Nivea 250cc','Cuidado Personal','7801152010005',3500,6),
        ('Alcohol Gel 350cc','Cuidado Personal','7801152013006',1800,12),
        ('Toallitas Humedas Babysec 80un','Cuidado Personal','7801152014003',2500,8),
        ('Hallulla Grande 1un','Panaderia','2000001',300,30),
        ('Marraqueta 1un','Panaderia','2000002',350,30),
        ('Pan Molde Ideal Blanco 600g','Panaderia','7801850500101',1800,12),
        ('Pan Molde Ideal Integral 600g','Panaderia','7801850500200',1900,8),
        ('Pan Hot Dog Framberry 6un','Panaderia','7801850500309',1500,8),
        ('Pan Hamburguesa Framberry 4un','Panaderia','7801850500408',1500,8),
        ('Jamon Cerdo San Jorge 200g','Fiambreria','7801201001001',2500,8),
        ('Jamon Pavo San Jorge 200g','Fiambreria','7801201002008',2800,8),
        ('Queso Laminado Gauda San Jorge 200g','Fiambreria','7801201003005',3000,6),
        ('Mortadela San Jorge 200g','Fiambreria','7801201004002',1500,8),
        ('Salame San Jorge 100g','Fiambreria','7801201005009',2200,8),
        ('Pate Cerdo San Jorge 100g','Fiambreria','7801201006006',1000,12),
        ('Helado Savory Mega Sandwich 100cc','Congelados','7801153001003',1200,16),
        ('Helado Savory Centella 120cc','Congelados','7801153002000',1000,16),
        ('Helado Trendy Frambuesa 100cc','Congelados','7801153003007',800,16),
        ('Nuggets Pollo Agrosuper 300g','Congelados','7802601001001',3000,6),
        ('Verduras Mixtas Congeladas 300g','Congelados','7801850600100',1500,8),
        ('Cigarro Lucky Strike Click 20un','Cigarrillos','7803001001001',4500,10),
        ('Cigarro Lucky Strike Original 20un','Cigarrillos','7803001002008',4200,10),
        ('Cigarro Pall Mall Azul 20un','Cigarrillos','7803001003005',4000,10),
        ('Cigarro Kent Switch 20un','Cigarrillos','7803001004002',4200,10),
        ('Encendedor Bic Maxi','Cigarrillos','7805001001001',1500,16)
    ) AS t(nombre, categoria, codigo_barra, precio_venta, stock_critico)
    WHERE NOT EXISTS (SELECT 1 FROM public.maestro_productos WHERE codigo_barra = t.codigo_barra AND empresa_id = v_empresa);

    -- Stock inicial para productos nuevos
    IF v_bodega_gral IS NOT NULL THEN
        INSERT INTO public.productos (maestro_producto_id, empresa_id, bodega_id, stock_actual, numero_lote, condicion, fecha_vencimiento, creado_en)
        SELECT mp.id, v_empresa, v_bodega_gral,
            CASE WHEN mp.categoria='Cigarrillos' THEN 20 WHEN mp.categoria='Bebidas' THEN 60 WHEN mp.categoria='Snacks' THEN 40 WHEN mp.categoria='Lacteos' THEN 30 WHEN mp.categoria='Panaderia' THEN 50 WHEN mp.categoria='Fiambreria' THEN 15 WHEN mp.categoria='Congelados' THEN 12 ELSE 24 END,
            'LOTE-'||TO_CHAR(NOW(),'YYYYMMDD'),
            'Bueno',
            CASE WHEN mp.categoria='Lacteos' THEN NOW()+INTERVAL '14 days' WHEN mp.categoria='Fiambreria' THEN NOW()+INTERVAL '21 days' WHEN mp.categoria='Panaderia' THEN NOW()+INTERVAL '3 days' WHEN mp.categoria='Congelados' THEN NOW()+INTERVAL '180 days' ELSE NOW()+INTERVAL '365 days' END,
            NOW()
        FROM public.maestro_productos mp
        WHERE mp.empresa_id = v_empresa
          AND NOT EXISTS (SELECT 1 FROM public.productos WHERE maestro_producto_id = mp.id);

        INSERT INTO public.movimientos (producto_id, tipo_movimiento, cantidad, empresa_id, motivo, condicion, creado_en)
        SELECT p.id, 'entrada', p.stock_actual, v_empresa, 'Stock inicial demo', 'Bueno', NOW()
        FROM public.productos p WHERE p.empresa_id = v_empresa AND p.creado_en >= NOW() - INTERVAL '1 minute';
    END IF;
END;
$$;
