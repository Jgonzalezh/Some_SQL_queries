----- Cantidades con minsal y covid

Set datefirst 1;
SET LANGUAGE spanish;

drop table if exists #CP_CargaAsistencial_MedicoAP;
select distinct ca.*,

	Mes = month(FECHA_INICIO),
	NMes = isnull( datename(mm,Fecha_Inicio),'Otros'),
	Anno = year(FECHA_INICIO),
	Dia = day(FECHA_INICIO),
	Hora = datepart(hh,HORA_INICIO),
	MediaHora = Convert(varchar, DATEADD(mi, (DATEDIFF(mi, 0, HORA_INICIO)/30*30), 0) ,24),
	DiaSemana = datename(weekday,FECHA_INICIO),
	NumeroSemana = datepart(week, FECHA_INICIO),
	TipoSiniestro_Origen =
		case TIPO_SINIESTRO_ORIG 
			when 1 then 'Trabajo'
			when 2 then 'Trayecto'
			when 3 then 'Enfermedad profesional'
			when 4 then 'No ley'
			else 'Otros' 
		END,

/*Diferenciar ingreso EP*/

	Clasif = case           
		when CL_MOV_DESC = 'Consulta Urgenc' then 'Ingreso'
		when CL_MOV_DESC = 'Preingreso EP'   then 'Preingreso EP'			
		when CL_MOV_DESC = 'Consulta Ambula' then 'Control Agendado'
		when CL_MOV_DESC = 'Consulta Espont' then 'Control Espontaneo'
		
		when CL_MOV_DESC = 'Apoyo Diagnosti' then 'Tareas Administrativas'
		when CL_MOV_DESC = 'Por desarrollo'  then 'Tareas Administrativas'
		when CL_MOV_DESC = 'Apoyo Tratamien' then 'Tareas Administrativas'

		when CL_MOV_DESC = 'Urgen.Telemed'   then 'Ingreso Telemedicina'
		when CL_MOV_DESC = 'Control Telemed' then 'Control Telemedicina'

		when CL_MOV_DESC = 'Urg.Telefónica' then 'Ingreso Telefonico'
		when CL_MOV_DESC = 'Control Telefon' then 'Control Telefonico'
        when CL_MOV_DESC = 'Vig de la Salud' then 'Vigilancia de la Salud'

		--when CL_MOV_DESC = 'Apoyo Diagnosti' then 'Apoyo Diagnostico'
		--when CL_MOV_DESC = 'Apoyo Diagnosti' then 'Control Agendado'



		else 'Otros'
		END,

	DiaSemanaEsp = isnull( CONCAT(datepart(weekday,FECHA_INICIO) ,'-',datename(weekday,FECHA_INICIO) ) , 'Otros'),
	DiaSemananum = isnull( DATEPART(weekday,Fecha_Inicio),99),
	AñoMes	= concat(year(FECHA_INICIO),'-',month(FECHA_INICIO)),
    Territorio=uo.Territorio_m
    ,Agencia=uo.agencia_m
    ,Centro=uo.centro_m

	INTO #CP_CargaAsistencial_MedicoAP

	FROM DF_CargaAsistencial ca
    
    left join di_uo_organizativa uo on
			ca.uo_tratamiento=uo.uo_tratamiento



/*
select * from DI_UO_Organizativa
	left join 
		DI_UOMedicaCentros
		on
		ca.UO_MEDICA = DI_UOMedicaCentros.[Unidad Organizativa]
	left join 
		DI_Centros
		on
		DI_UOMedicaCentros.CD_Centro = DI_Centros.CD_Centro
*/
	WHERE 
		Ind_Anulacion <> 'D' and Ind_Anulacion <> 'X' and (uo.UO_MEDICA like '%MAPRI%')-- or uo.Uo_Tratamiento like '%MDT' or uo.Uo_Tratamiento like '%CVSA%') --  
		and uo.Uo_Medica not in('PECMTMT','PECMSM','PECMCX','PECMCMED','PECMIMG','PECMENFE','PECMHOSP','PECMAPRI','PECMPROC')
		and Fecha_Inicio <= getdate()
		--and DI_Centros.prioridad = 1

        /*Quitar filtro siniestro*/
		--and Siniestro is not null
		and datepart(yyyy,fecha_inicio) >= 2018




drop table if exists #CP_Capacity_MedicoAP;

Select 
    Territorio
    ,Agencia
    ,Centro
    ,fecha_inicio
    ,NumeroSemana
    , MINSAL=Case when Covid=1 and MINSAL=1 then sum(Ingreso+IngresoEP+PreIngresoEP+[Control agendado]+Control_esp+Administrativo) else 0 end
    , MINSAL_NO_COVID=Case when Covid=0 and MINSAL=1 then sum(Ingreso+IngresoEP+PreIngresoEP+[Control agendado]+Control_esp+Administrativo) else 0  end
    , ATENCIONES_COVID=Case when Covid=1 and MINSAL=0 then sum(Ingreso+IngresoEP+PreIngresoEP+[Control agendado]+Control_esp+Administrativo)  else 0 end
    , ATENCIONES=Case when Covid=0 and MINSAL=0 then sum(Ingreso+IngresoEP+PreIngresoEP+[Control agendado]+Control_esp+Administrativo)  else 0 end
   
    /*,sum(Ingreso) as Ingreso
    ,sum([Control agendado]) as [Control Agendado]
    ,sum(Administrativo) as [Administrativo]
    ,sum(Otros) as Otros*/
    , atenciones_totales= sum(Ingreso+IngresoEP+PreIngresoEP+[Control agendado]+Control_esp+Administrativo)
   
    ,sum(Ingreso)            as Ingreso
    ,sum(IngresoEP)          as IngresoEP
    ,sum(PreIngresoEP)       as PreIngresoEP
    ,sum([Control agendado]) as [Control Agendado]
    ,sum(Administrativo)     as [Administrativo]
    ,sum(Otros)              as Otros
    ,sum(Control_esp)        as Control_espnt

    --,Tiempo_total = sum(Ingreso)*20.6 + sum(IngresoEP)*37 + sum(PreIngresoEP)*28 + sum([Control agendado])*13.9 + sum(Administrativo)*6

	into #CP_Capacity_MedicoAP

    from (
                SELECT
                Territorio
                ,Agencia
                ,Centro
                ,fecha_inicio
                ,NumeroSemana
                ,Covid
                ,MINSAL
                /*,Ingreso			 = case when Clasif in ('Ingreso','Preingreso EP','Control Espontaneo')		then cantidad else 0 end
                ,[Control Agendado]  = case when Clasif =	'Control Agendado'									then cantidad else 0 end
                ,[Administrativo]    = case when Clasif =	'Tareas Administrativas'							then cantidad else 0 end
                ,[Otros]			 = case when Clasif not in ('Ingreso','Preingreso EP','Control Espontaneo','Control Agendado','Tareas Administrativas')  then cantidad else 0 end 
                */

                ,Ingreso			    = case when Clasif in  ('Ingreso','Ingreso Telemedicina','Ingreso Telefonico')       	and  TipoSiniestro_Origen not in ('Enfermedad profesional') then cantidad else 0 end
                --,Ingreso			    = case when (Clasif ='Ingreso' or  Clasif ='Ingreso Telemedicina' or Clasif='Ingreso Telefonico')       	and  TipoSiniestro_Origen!='Enfermedad profesional' then cantidad else 0 end
                
                ,Control_esp           = case when Clasif = 'Control Espontaneo'	                                                        then cantidad else 0 end
                ,IngresoEP			    = case when Clasif in  ('Ingreso','Ingreso Telemedicina','Ingreso Telefonico')            	and  TipoSiniestro_Origen in ('Enfermedad profesional')     then cantidad else 0 end
                ,PreingresoEP           = case when Clasif = 'Preingreso EP'	                                                            then cantidad else 0 end
                --,IngresoEP	        = case when Clasif in ('Ingreso','Preingreso EP','Control Espontaneo')		then cantidad else 0 end
                ,[Control Agendado]     = case when Clasif in ('Control Agendado','Control Telemedicina','Control Telefonico')								then cantidad else 0 end
                ,[Administrativo]       = case when Clasif in	('Tareas Administrativas', 'Vig de la Salud')							then cantidad else 0 end
                ,[Otros]			    = case when Clasif not in ('Ingreso','Ingreso Telemedicina','Ingreso Telefonico','Preingreso EP','Control Espontaneo','Control Agendado','Control Telemedicina','Control Telefonico','Tareas Administrativas', 'Vig de la Salud')  then cantidad else 0 end 


                --,Ingreso			 = case when tipoDemanda = 'Ingreso'		  then cantidad else 0 end
                --,[Control Agendado]  = case when tipoDemanda = 'Control Agendado' then cantidad else 0 end
                --,[Administrativo]    = case when tipoDemanda = 'Administrativo'	  then cantidad else 0 end
                --,[Otros]			 = case when tipoDemanda not in ('Ingreso','Control Agendado','Administrativo')  then cantidad else 0 end 
                
                FROM
                    ( 
                    Select 
                        Territorio
                        ,agencia
                        ,centro
                        ,clasif
                        --,TipoDemanda
                        ,fecha_inicio
                        ,NumeroSemana
                        ,count(1) as Cantidad
                        ,TipoSiniestro_Origen
                        , Covid=case when
                            bb.Siniestro_Covid19 is not null then 1 else 0 END
                        , MINSAL= case when
                            cc.Id_Siniestro is not null then 1 else 0 end
                        --,Siniestro, bb.Siniestro_Covid19, cc.Id_Siniestro


                        from #CP_CargaAsistencial_MedicoAP aa
                        left join [dbo].[Siniestros_COVID19] bb on cast(aa.Siniestro as int)=cast(substring(bb.Siniestro_Covid19,2,len(bb.Siniestro_Covid19) )as int )
                        left join (select distinct hh.id_siniestro from [Progreso_Actual] hh) cc on aa.Siniestro=cc.Id_Siniestro

                        where Fecha_Inicio>'1-mar-2020' --and Siniestro=6708019
                        group by
                        Territorio
                        ,agencia
                        ,centro
                        ,clasif
                        --,TipoDemanda
                        ,fecha_inicio
                        ,NumeroSemana
                        ,TipoSiniestro_Origen
                        , cc.Id_Siniestro
                        , bb.Siniestro_Covid19
                        --order by case when
                        --    bb.Siniestro_Covid19 is not null then 1 else 0 END desc,  case when
                        --    cc.Id_Siniestro is not null then 1 else 0 end desc
                ) as hhh
  
    ) as hhhh

    group by 
    Territorio
    ,Agencia
    ,Centro
    ,fecha_inicio
    ,NumeroSemana
    ,Covid
    ,MINSAL

--

select Territorio, Agencia, Centro, Fecha_Inicio, NumeroSemana, MINSAL=sum(MINSAL), MINSAL_NO_COVID=sum(MINSAL_NO_COVID), ATENCIONES=sum(ATENCIONES), ATENCIONES_COVID=sum(ATENCIONES_COVID) from #CP_Capacity_MedicoAP
--where NumeroSemana=17 and Agencia='Santiago' and Centro='Santiago' and Fecha_Inicio='2020-04-21'
group by Territorio, Agencia, Centro, Fecha_Inicio, NumeroSemana
