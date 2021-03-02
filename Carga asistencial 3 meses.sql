SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE   Procedure [dbo].[sp_CP_CargaAsist_desv_3M_JGH]
as 


-----------------------------------------------------------------------------------------------------------------------
--                                             HORARIO
-----------------------------------------------------------------------------------------------------------------------

set language Spanish;
set datefirst 1;
declare @semana int
set @semana=13;

drop table if exists #vw_horariocentros_MediaHora;

(select
unp.centro,
diasem,
convert(varchar,cast(unp.Mediahora as time),20) as Mediahora
,unp.horario

into #vw_horariocentros_MediaHora
from di_horariocentrosmh H

UNPIVOT  
   (Horario FOR Centro IN   
      (
	  Alameda
	  ,Amolanas
	  ,Ancud
	  ,Angol	
	  ,Antofagasta
	  ,Arauco
	  ,Arica
	  ,[Aysén]	
	  ,Buin
	  ,Cabildo
	  ,Cabrero
	  ,Calama
	  ,Caldera
	  ,Cañete
	  ,Castro
	  ,Cauquenes	
	  ,Chañaral
	  ,Chillán
	  ,Colina
	  ,Concepción
	  ,Constitución
	  ,Copiapó
	  ,Coquimbo
	  ,Coronel
	  ,Coyhaique
	  ,Curanilahue
	  ,Curicó
	  ,Egaña
	  ,[El Salvador]
	  ,[Hospital del Trabajador]
	  ,Hualañe
	  ,Illapel
	  ,Iquique
	  ,[La Calera]
	  ,[La Florida]
	  ,[La Ligua]
	  ,[La Reina]
	  ,[La Rosa]
	  ,[La Serena]
	  ,[La Unión]
	  ,Laja
	  ,[Las Condes]
	  ,Linares
	  ,[Los Andes]
	  ,[Los Ángeles]
	  ,[Los Loros]
	  ,Maipú
	  ,Mejillones
	  ,Melipilla
	  ,Mininco
	  ,Nacimiento
	  ,Natales
	  ,Osorno
	  ,Ovalle	
	  ,Paine
	  ,[Parque Las Américas]
	  ,Parral
	  ,Peñaflor
	  ,[Policlínico Especialidades Concepción]
	  ,Providencia,
	  [Puente Alto]
	  ,[Puerto Montt]
	  ,[Punta Arenas]
	  ,Purranque
	  ,Quellón
	  ,Quemchi
	  ,Quilicura
	  ,Rancagua
	  ,Rengo
	  ,[Río Bueno]
	  ,[San Antonio]
	  ,[San Bernardo]
	  ,[San Felipe]
	  ,[San Fernando]
	  ,[San Javier]
	  ,[San Miguel]
	  ,[San Vicente]
	  ,[Santa Cruz]
	  ,Santiago
	  ,Talagante	
	  ,Talca
	  ,Talcahuano
	  ,Temuco
	  ,Tocopilla
	  ,Valdivia
	  ,Vallenar
	  ,Valparaíso
	  ,[Vespucio Oeste]
	  ,Victoria
	  ,Vicuña
	  ,Villarrica
	  ,[Viña del Mar]   	  
	 )  
)unp
);

-- select * from #vw_horariocentros_MediaHora where centro='Providencia' order by horario and diasem='Miércoles' and Mediahora='16:00:00'
-----------------------------------------------------------------------------------------------------------------------------

drop table if exists #seriedetiempo;
select distinct 
	fc.*
	,mh.MediaHora 

	into #seriedetiempo
	from (
		select 
			CAST(Fecha as date) as fecha, 
			DiaSem=
				case           
					when datepart(dw, Fecha) = 1 then 'Lunes'
					when datepart(dw, Fecha) = 2 then 'Martes'
					when datepart(dw, Fecha) = 3 then 'Miércoles'
					when datepart(dw, Fecha) = 4 then 'Jueves'
					when datepart(dw, Fecha) = 5 then 'Viernes'
					when datepart(dw, Fecha) = 6 then 'Sábado'
					when datepart(dw, Fecha) = 7 then 'Domingo'
					else 'Otro'
				END	
			from DI_Feriados) fc
	left join(
		select cast(DiaSem as varchar) DiaSem
		,convert(varchar
		,cast(Mediahora as time),20) as Mediahora 
		from #vw_horariocentros_MediaHora) mh
		on
		fc.DiaSem = mh.Diasem

--------------------------------------------------------------------------------------------------------------------------------
--select * from #seriedetiempo order by fecha, DiaSem, MediaHora 
drop table if exists #union;
(
select
	HC.Centro,
	T.fecha,
	HC.DiaSem,
	HC.horario,
	convert(varchar, HC.Mediahora, 20) as MediaHora

	into #union
	from #seriedetiempo T
	left join 
		#vw_horariocentros_MediaHora HC
		on 
		concat(HC.DiaSem,'-',HC.Mediahora)=concat(T.DiaSem,'-', T.MediaHora)
);
---select * from  #union
-------------------------------------------------------------------------------------------------------------------------
--									SAP - DEFINIR CANTIDADES PARA CADA ATENCIÓN
-------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------
-------------------Se obtiene la cantidad de atenciones por "clasif" desde CP_CargaAsistencial_MedicoAP------------------
-------------------------------------------------------------------------------------------------------------------------
;drop table if exists #VW_Z_PERCENTILES0;
(
	Select 
		Episodio
		,Centro
		,Bp_Paciente
		,Clasif
		,DiaSemana
		,Hora
		,MediaHora = Convert(varchar, DATEADD(mi, (DATEDIFF(mi, 0, HORA_INICIO)/30*30), 0) ,24),
		fecha_inicio as fecha,
		Año = datepart(yyyy, fecha_inicio),
		AñoSemana = Concat(datepart(yyyy, fecha_inicio),'-',datepart(wk, fecha_inicio)),
		NumeroSemana,
		--Origen = case when centro in (select centro from #CEntrosSGP) then 'SGP+SAP' else 'SAP'end,

		PreIngresoEPSAP			= case when Clasif = 'PreIngreso EP' then count(1) else 0 end,
		IngresoSAP				= case when Clasif = 'Ingreso' AND TipoSiniestro_Origen not in ('Enfermedad Profesional')  then count(1) else 0 end,
		IngresoEPSAP			= case when Clasif = 'Ingreso' AND TipoSiniestro_Origen ='Enfermedad Profesional' then count(1) else 0 end,
		ControlAgendadoSAP		= case when Clasif = 'Control Agendado' then count(1) else 0 end,
		ControlEspontaneoSAP	= case when Clasif = 'Control Espontaneo' then count(1) else 0 end,
		TareasAdministrativasSAP = case when Clasif= 'Tareas Administrativas' then count(1) else 0 end

		into #VW_Z_PERCENTILES0
		from  CP_CargaAsistencial_MedicoAP

/*		left join
		DI_CENTROS
		on
		CP_CargaAsistencial_MedicoAP.centro = DI_CENTROS.sede
*/
		where
			-- DI_CENTROS.prioridad = 1 and
			fecha_inicio >= dateadd(week, -(@semana),getdate())
		group by 
			Episodio, centro, Bp_Paciente,DiaSemana,clasif, hora,HORA_INICIO, fecha_inicio,datepart(yyyy, fecha_inicio),NumeroSemana, TipoSiniestro_Origen
)
--select * from DI_CENTROS --useless
--select * from CP_CargaAsistencial_MedicoAP
-------------------------------------------------------------------------------------------------------------------------
------------------Se suman el total de Atenciones Variables y Controles en cada Centro por semana -----------------------
------------------Se multiplica por la duracion para obtener los tiempos del total de atenciones ------------------------
-------------------------------------------------------------------------------------------------------------------------

;drop table if exists #VW_Z_PERCENTILES1;
(
SELECT
	centro, 
	--fecha, 
	AñoSemana,
	--DiaSemana, 
	--mediahora,

	sum(PreIngresoEPSAP)*28+sum(IngresoSAP)*(20.6)+sum(IngresoEPSAP)*37+sum(ControlEspontaneoSAP)*15+sum(TareasAdministrativasSAP)*6 as TiempoDemandaVariableSAP,
	sum(ControlAgendadoSAP)*15	as TiempoControlesSAP,
	
	sum(PreIngresoEPSAP)+sum(IngresoSAP)+sum(IngresoEPSAP)+sum(ControlEspontaneoSAP)+sum(TareasAdministrativasSAP) as CantidadDemandaVariableSAP,
	sum(ControlAgendadoSAP)	as CantidadControlesSAP

	into #VW_Z_PERCENTILES1
	from #VW_Z_PERCENTILES0
	group by centro,AñoSemana
);
--SELECT * FROM #VW_Z_PERCENTILES1 where Centro='Coronel'
-------------------------------------------------------------------------------------------------------------------------
----------------------------------Se calcula la cantidad semanal de SAP,-------------------------------------------------
--------------------------para luego ser multiplicada por el porcentaje semanal de SGP*----------------------------------
-------------------------------------------------------------------------------------------------------------------------

drop table if exists #percentil75_SemanalSAP;
(
select DISTINCT
	Centro,

	TiempoDemandaVariableSAP_per	= PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY TiempoDemandaVariableSAP) OVER (PARTITION BY Centro),
	TiempoControlesSAP_per			= PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY TiempoControlesSAP) OVER (PARTITION BY Centro),

	CantidadDemandaVariableSAP_per	= PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CantidadDemandaVariableSAP) OVER (PARTITION BY Centro),
	CantidadControlesSAP_per		= PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CantidadControlesSAP) OVER (PARTITION BY Centro)


	into #percentil75_SemanalSAP
	from #VW_Z_PERCENTILES1
);
--select * from #percentil75_SemanalSAP where centro='Alameda'
-------------------------------------------------------------------------------------------------------------------------
--                                    SGP - OBTENER CURVA DE ATENCION SEMANAL
-------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------
------------------------------------------------DATOS SGP ---------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------

drop table if exists #vw_evolucionsemanal;
(
	select  
		ca.Centro
		,Rut_Paciente
		,ticket
		,Fecha
		,Hora_Inicia
		,Hora_Fin
		,Cargo
		,Estado
		,Minutos
		,ca.Uo_Medica
		,Clasif 
		,Hr_inicio
		,ca.Anno
		,ca.NumeroSemana
		,Diasemana as DiaSemanaNombre
		,MediaHora = cast(DATEADD(mi, (DATEDIFF(mi, 0, hora_inicia)/30*30), 0) as time)
        ,Fila,

		PreIngresoEP			= case when Estado in ('box_atencion','espera_box_atencion') and ca.Clasif in ('Preingreso EP') then count (1) else 0 end,
		Ingreso					= case when Estado in ('box_atencion','espera_box_atencion') and ca.Clasif in ('Ingreso') AND ca.TipoSiniestro_Origen not in ('Enfermedad Profesional') then count (1) else 0 end,
		IngresoEP				= case when Estado in ('box_atencion','espera_box_atencion') and ca.Clasif in ('Ingreso') AND ca.TipoSiniestro_Origen= ('Enfermedad Profesional')then count (1) else 0 end,
		ControlEspontaneo		= case when Estado in ('box_atencion','espera_box_atencion') and ca.Clasif in ('Control Espontaneo') then count (1) else 0 end,
		ControlAgendado			= case when Estado in ('box_atencion','espera_box_atencion') and ca.Clasif in ('Control Agendado') then count (1) else 0 end,
		TareasAdministrativas	= case when Estado in ('box_atencion','espera_box_atencion') and ca.Clasif in ('Tareas Administrativas') then count (1) else 0 end

		into #vw_evolucionsemanal
		from CP_SGP
		
		left join 
			[az-analytics].[dbo].[DF_Interlocutor_Comercial] 
			on 
			Rut_Paciente=[az-analytics].[dbo].[DF_Interlocutor_Comercial].Rut
		
		left join 
			CP_CargaAsistencial_MedicoAP ca
			on 
			[az-analytics].[dbo].[DF_Interlocutor_Comercial].Numero_BP=ca.Bp_Paciente
			and fecha=ca.Fecha_Inicio
			--and Hora_Inicio between (Dateadd(minute,-300,Hora_Inicia)) and (Dateadd(minute,300,Hora_Inicia))

		where 
			Fila in ('A','B','M')
			and ca.Centro NOT IN ('CAA', 'SEL', 'Urgencia', 'CEM 1ER PISO', 'CEM 2DO PISO', 'CEM 3ER PISO', 'CEM 4TO PISO', 'CEM 5TO PISO', 'CEM 6TO PISO', 'CEM IMAGENOLOGIA', 'CEM RAYOS', 'SALUD MENTAL')
			And fecha_inicio >= dateadd(week, -@semana,getdate())
			and validacion=1

		Group by ca.Centro, Rut_Paciente, ticket, Fecha, Hora_Inicia, Hora_Fin, Cargo,Estado,Minutos,ca.Uo_Medica, ca.Clasif,Hr_inicio,ca.Anno,ca.NumeroSemana,Diasemana,MediaHora, ca.TipoSiniestro_Origen, Fila 
);
-- select * from #vw_evolucionsemanal;
-- select * from CP_SGP
-- select * from [az-analytics].[dbo].[DF_Interlocutor_Comercial] 
-- select * from CP_CargaAsistencial_MedicoAP
-------------------------------------------------------------------------------------------------------------------------
----------------------------Obtener numero de box-atencion por cada atencion paciente------------------------------------
-------------------------------------------------------------------------------------------------------------------------

drop table if exists #Atenciones
(
select 
	*, 
	Numerofila = ROW_NUMBER() Over(Partition by centro, fecha, Rut_Paciente, ticket Order By centro, fecha, Hora_Inicia)
	into #Atenciones
	From #vw_evolucionsemanal
);
--select * from #Atenciones
-------------------------------------------------------------------------------------------------------------------------
---------------------------------Obtener primer box-atencion de atencion paciente ---------------------------------------
-------------------------------------------------------------------------------------------------------------------------

drop table if exists #vw_evolucionsemanal2
(
select 
	Centro, Rut_Paciente, Fecha, Hora_Inicia, Hora_Fin, Cargo, Estado, Minutos, Uo_Medica, Clasif,
	Anno,
	NumeroSemana,
	DiaSemanaNombre,
	MediaHora,
	PreIngresoEP,
	Ingreso,
	IngresoEP,
	ControlEspontaneo,
	ControlAgendado,
	TareasAdministrativas

	into #vw_evolucionsemanal2
	from #Atenciones
	where Numerofila =1
);
--select * from  #vw_evolucionsemanal2
-------------------------------------------------------------------------------------------------------------------------
-------------------------------------------BASE CENTROS CON SGP ---------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------
drop table if exists #CentrosSGP;
(
select 
	centro 
	into #CentrosSGP
	from CP_SGP
	Group by centro)

--select * from #CentrosSGP 
-----------------------------------------------------------------------------------------------------------------------------
---------------------------------------CREACION HORA FIN PARA DATOS SIN SGP--------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------
-- Se agrega tiempo a Hora Inicio de SAP. El tiempo agregado considera tiempos estimativos de admision, espera_box_atencion y box_atencion
-- admision ingresos = 6 min, admision controles = 2 min, espera_box_atencion= 10 min
-- Tareas Administrativas no consideras admision, ni espera box
-----------------------------------------------------------------------------------------------------------------------------

drop table if exists #vw_evolucionsemanalsinSGP;
(
select
	ca.Centro
	,Rut_Paciente = ' '
	,Fecha_Inicio as fecha
	,Hora_Inicio as Hora_Inicia 
	,Hora_Fin=
		case           
			when Clasif = 'Ingreso' AND TipoSiniestro_Origen not in ('Enfermedad Profesional')  then DATEADD(minute,36.6,Hora_Inicio)
			when Clasif = 'Ingreso' AND TipoSiniestro_Origen = ('Enfermedad Profesional') then DATEADD(minute,53,Hora_Inicio)
			when Clasif = 'PreIngreso EP' then DATEADD(minute,44,Hora_Inicio)
			when Clasif = 'Control Agendado' then DATEADD(minute,27,Hora_Inicio)
			when Clasif = 'Control Espontaneo'  then DATEADD(minute,31,Hora_Inicio)
			when Clasif = 'Tareas Administrativas'  then DATEADD(minute,6,Hora_Inicio)
		END
	,Cargo=' '
	,Estado= 'box_atencion'
	,Minutos=0
	,Uo_Medica
	,clasif
	,Anno = datepart(yyyy, Fecha_Inicio)
	,NumeroSemana
	,DiaSemana as DiaSemanaNombre
	,MediaHora = Convert(varchar, DATEADD(mi, (DATEDIFF(mi, 0, HORA_INICIO)/30*30), 0) ,24)

	,PreIngresoEP= case when Clasif = 'PreIngreso EP' then count(1) else 0 end
	,Ingreso = case when Clasif = 'Ingreso' AND TipoSiniestro_Origen not in ('Enfermedad Profesional') then count(1) else 0 end
	,IngresoEP = case when Clasif = 'Ingreso' AND TipoSiniestro_Origen = ('Enfermedad Profesional') then count(1) else 0 end
	,ControlAgendado = case when Clasif = 'Control Agendado' then count(1) else 0 end
	,ControlEspontaneo = case when Clasif = 'Control Espontaneo' then count(1) else 0 end
	,TareasAdministrativas = case when Clasif='Tareas Administrativas' then count(1) else 0 end

	into #vw_evolucionsemanalsinSGP
	from CP_CargaAsistencial_MedicoAP ca

	left join #CentrosSGP
	on ca.Centro = #CentrosSGP.centro
	where #CentrosSGP.centro is null


	Group by ca.Centro, Fecha_Inicio, Hora_Inicio, NumeroSemana, DiaSemana, Uo_Medica, clasif, TipoSiniestro_Origen
);
-- select * from #vw_evolucionsemanalsinSGP where Centro in ('Egaña', 'Osorno','Ancud')
-------------------------------------------------------------------------------------------------------------------------
--------------------------------------------UNION DATOS SGP Y SIN SGP ---------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------

drop table if exists #VW_evolucionsemanalunion;
(
select *
	into #VW_evolucionsemanalunion
	From #vw_evolucionsemanal2 
	Union ALL (select * from #vw_evolucionsemanalsinSGP)
);

-- select * from #VW_evolucionsemanalunion where Centro='Ancud'
---------------------------------------------------------------------------------------------------------------------------------
--------CONTEO TOTAL POR ATENCIONES VARIABLES(Preingreso EP, Ingreso, Ingreso EP, ControlEspontaneo, TareasAdministrativas)------
-- Y CONTROLES(Control Agendado). SE LES MULTIPLICA LA DURACION DE CADA TIPO DE ATENCION PARA OBTENER CONTEO DE TIEMPOS ---------
---------------------------------------------------------------------------------------------------------------------------------
drop table if exists #vw_evolucionsemanalunion2;
(
SELECT
	centro
	,Fecha
	,NumeroSemana
	,DiaSemanaNombre
	,MediaHora

	,sum(PreIngresoEP)+sum(Ingreso)+sum(IngresoEP)+sum(ControlEspontaneo)+sum(TareasAdministrativas) as TotalDemandaVariableAtencion
	,sum(ControlAgendado) as TotalControlesAtencion
	,sum(PreIngresoEP*28/30)+sum(Ingreso*20.6/30)+sum(IngresoEP*37/30)+sum(ControlEspontaneo*15/30)+sum(TareasAdministrativas*6/30) as Tiempo_DmdVar
	,sum(ControlAgendado*15/30) as Tiempo_dmdControles

	into #vw_evolucionsemanalunion2
	from #VW_evolucionsemanalunion
	group by centro, fecha,NumeroSemana, DiaSemanaNombre, mediahora
);

--select * from #vw_evolucionsemanalunion2
---------------------------------------------------------------------------------------------------------------------------------
--------------------------------UNION DATOS TIEMPOS ATENCIONES SGP CON BASE HORARIOS---------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
drop table if exists #unionSGPHC;
(
select 
	HC.Centro,
	HC.DiaSem,
	HC.fecha,
	HC.MediaHora,

	D.TotalDemandaVariableAtencion,
	D.TotalControlesAtencion,
	D.Tiempo_DmdVar,
	D.Tiempo_dmdControles

	into #unionSGPHC
	from #union HC
	left join 
		#vw_evolucionsemanalunion2 D
		on HC.centro=D.Centro
		and  HC.fecha=D.fecha
		and  HC.Diasem=D.DiaSemanaNombre
		and  cast(HC.MediaHora as time)=D.MediaHora
);
--select * from #unionSGPHC where TotalControlesAtencion is not null
---------------------------------------------------------------------------------------------------------------------------------
----------------------------------REEMPLAZAR NULL POR CERO EN HORARIOS SIN DEMANDA-----------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
drop table if exists #unionSGPHCsinnull;
(
select

	Centro,
	DiaSem,
	fecha,
	MediaHora,

	TotalDemandaVariableAtencion		= case when TotalDemandaVariableAtencion is null then 0 else TotalDemandaVariableAtencion END,
	TotalControlesAtencion				= case when TotalControlesAtencion is null then 0 else TotalControlesAtencion END,

	Tiempo_DmdVar						= case when Tiempo_DmdVar	   is null then 0 else Tiempo_DmdVar	   END ,
	Tiempo_dmdControles					= case when  Tiempo_dmdControles	  is null then 0 else Tiempo_dmdControles  END

	into #unionSGPHCsinnull
	from #unionSGPHC
);
---------------------------------------------------------------------------------------------------------------------------------
----------------------------OBTENER PERCENTIL 75 DE LOS TIEMPOS DE ATENCION POR CENTRO, DIA Y MEDIAHORA -------------------------
---------------------------------------------------------------------------------------------------------------------------------
drop table if exists #percentil75_mediahora;
(
select distinct
	Centro, 
	DiaSem, 
	MediaHora,

	TotalDemandaVariableAtencion_per	= PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY TotalDemandaVariableAtencion) OVER (PARTITION BY Centro, DiaSem, MediaHora),
	TotalControlesAtencion_per			= PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY TotalControlesAtencion) OVER (PARTITION BY Centro, DiaSem, MediaHora)

	into #percentil75_mediahora
	from #unionSGPHCsinnull
	Group by Centro, Diasem, Mediahora, TotalDemandaVariableAtencion, TotalControlesAtencion
);
--- correr lo siguiente para ver las diferencias de SGP y SAP
--select Centro,sum(TotalDemandaVariableAtencion_per) as variable,sum(TotalControlesAtencion_per) as controles  from #percentil75_mediahora where Centro in ('Alameda','Ancud','Angol', 'Concepción', 'La Florida','Las Condes') group by Centro order by Centro;
--select Centro, CantidadDemandaVariableSAP_per, CantidadControlesSAP_per from #percentil75_SemanalSAP where Centro in ('Alameda','Ancud','Angol', 'Concepción', 'La Florida','Las Condes') order by Centro

--drop table if exists #Devest_bloque
drop table if exists #DEVS_M_AP
select 	Centro, 
	DiaSem, 
	MediaHora,

	Devest_variable	= isnull(STDEV(Tiempo_DmdVar),0),
	Devest_controles = 	isnull(STDEV(Tiempo_dmdControles),0)
--into #Devest_bloque
into #DEVS_M_AP
from #unionSGPHCsinnull
group by Centro, DiaSem, MediaHora;

--select * from CP_JGH_DEVS_M_AP where Centro='Alameda' and DiaSem in ('Lunes','Domingo') order by MediaHora

---------------------------------------------------------------------------------------------------------------------------------
----------------------------------CONTEO PERCENTILES 75 DE TIEMPOS DE ATENCION --------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
drop table if exists #sumapercentil75;
(
select
	Centro,

	sum(TotalDemandaVariableAtencion_per)	as sumadvariable,
	sum(TotalControlesAtencion_per)			as sumacontrol

	into #sumapercentil75
	from #percentil75_mediahora
	group by Centro
);
 --correr lo siguiente para ver las diferencias de SGP y SAP
--select * from #sumapercentil75 where Centro in ('Alameda','Ancud','Angol', 'Concepción', 'La Florida','Las Condes') order by Centro;
-- select Centro, CantidadDemandaVariableSAP_per, CantidadControlesSAP_per from #percentil75_SemanalSAP where Centro in ('Alameda','Ancud','Angol', 'Concepción', 'La Florida','Las Condes') order by Centro
---------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------CREAR CURVA PORCENTUAL SEMANAL ---------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
drop table if exists #porcentaje_mediahora;
(
select distinct
	per.Centro, per.DiaSem, per.MediaHora, 

	PorcentajeTotalDemandaVariableAtencion_per	= case when suma.sumadvariable	>0 then cast(per.TotalDemandaVariableAtencion_per as decimal(10,5))/cast(suma.sumadvariable as decimal(10,5)) else 0 end,
	PorcentajeTotalControlesAtencion_per		= case when suma.sumacontrol	>0 then cast(per.TotalControlesAtencion_per as decimal(10,5))/cast(suma.sumacontrol as decimal(10,5)) else 0 end

	into #porcentaje_mediahora
	from #percentil75_mediahora per
	left join
		#sumapercentil75 suma
		on
		per.centro=suma.centro
);
/*
select * from #porcentaje_mediahora
select Centro, sum( PorcentajeTotalDemandaVariableAtencion_per),sum(PorcentajeTotalControlesAtencion_per) from #porcentaje_mediahora group by Centro
select Centro, DiaSem, sum( PorcentajeTotalDemandaVariableAtencion_per),sum(PorcentajeTotalControlesAtencion_per) from #porcentaje_mediahora group by Centro, DiaSem order by Centro
*/
---------------------------------------------------------------------------------------------------------------------------------
-----------------------UNIR CURVA CON CANTIDADES DE ATENCIONES SAP, OBTENIEDO PREDICCION DE DEMANDA -----------------------------
---------------------------------------------------------------------------------------------------------------------------------
drop table if exists #demandahoraria;
(
	select distinct
	#porcentaje_mediahora.Centro
	,#porcentaje_mediahora.DiaSem
	,#porcentaje_mediahora.MediaHora,

	--Tiempos
	PorcentajeTotalDemandaVariableAtencion_per	*persap.TiempoDemandaVariableSAP_per	*1.00 as DemandaTVariableAtencion,
	PorcentajeTotalControlesAtencion_per		*persap.TiempoControlesSAP_per			*1.00 as DemandaTControlesAtencion,
	--Cantidades
	PorcentajeTotalDemandaVariableAtencion_per	*persap.CantidadDemandaVariableSAP_per	*1.00 as DemandaQVariableAtencion,
	PorcentajeTotalControlesAtencion_per		*persap.CantidadControlesSAP_per		*1.00 as DemandaQControlesAtencion

	into #demandahoraria
	from #porcentaje_mediahora
	left join
		#percentil75_SemanalSAP persap
		on
		#porcentaje_mediahora.centro=persap.centro
);
--select * from #demandahoraria
-------------------------------------------------------------------------------------------------------------------------
---------------------------------------Demanda en Tiempo y Cantidad Médicos AP-------------------------------------------
-------------------------------------------------------------------------------------------------------------------------

drop table if exists #union1;
(
select

	Centro,
	DiaSem,
	--horario,
	MediaHora,
--Tiempos
	--DemandaVariableAtencion
	TDV3	= case when DemandaTVariableAtencion is null	 then 0 else round(DemandaTVariableAtencion,5,0) end,
	--DemandaControlesAtencion
	TCA3	= case when DemandaTControlesAtencion is null then 0 else round(DemandaTControlesAtencion,5,0) end,

--Cantidad
	--DemandaVariableAtencion
	QDV3	= case when DemandaQVariableAtencion is null	 then 0 else round(DemandaQVariableAtencion,5,0) end,
	--DemandaControlesAtencion
	QCA3	= case when DemandaQControlesAtencion is null then 0 else round(DemandaQControlesAtencion,5,0) end

into #union1
from #demandahoraria
--where centro in ('Concepción')
);
select * from #union1;
select * from #DEVS_M_AP;

drop table if exists #Union_2
select aa.*, bb.Devest_variable, bb.Devest_controles
into #Union_2 
from #union1 aa
left join #DEVS_M_AP bb on aa.Centro=bb.Centro and aa.DiaSem=bb.DiaSem and aa.MediaHora=bb.MediaHora


--select * from #Union_2
--****************************************************************************************************************************
;drop table if exists #3Meses
select f2.*, Lapse = '3 Meses' into #3Meses from #union_2 f2 order by centro, diasem,mediahora
;

INSERT INTO CP_HerramientaTurnos_desv_JGH
SELECT * FROM #3Meses
GO
