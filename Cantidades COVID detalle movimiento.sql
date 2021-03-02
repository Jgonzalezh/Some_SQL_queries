----- Cantidades con minsal y covid


drop table if exists #CP_Capacity_MedicoAP;

Select 
    Territorio
    ,Agencia
    ,Centro
    ,fecha_inicio
    ,NumeroSemana
    ,Tipo=Case when Covid=1 and MINSAL=1 then 'MINSAL Covid'
        when Covid=0 and MINSAL=1 then 'MINSAL No Covid'
        when Covid=1 and MINSAL=0 then 'Otros Covid'
        Else'Otros' end
    /*,sum(Ingreso) as Ingreso
    ,sum([Control agendado]) as [Control Agendado]
    ,sum(Administrativo) as [Administrativo]
    ,sum(Otros) as Otros*/

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

                ,Ingreso			    = case when Clasif = 'Ingreso'         	and  TipoSiniestro_Origen not in ('Enfermedad profesional') then cantidad else 0 end
                ,Control_esp           = case when Clasif = 'Control Espontaneo'	                                                        then cantidad else 0 end
                ,IngresoEP			    = case when Clasif = 'Ingreso'         	and  TipoSiniestro_Origen in ('Enfermedad profesional')     then cantidad else 0 end
                ,PreingresoEP           = case when Clasif = 'Preingreso EP'	                                                            then cantidad else 0 end
                --,IngresoEP	        = case when Clasif in ('Ingreso','Preingreso EP','Control Espontaneo')		then cantidad else 0 end
                ,[Control Agendado]     = case when Clasif =	'Control Agendado'									then cantidad else 0 end
                ,[Administrativo]       = case when Clasif =	'Tareas Administrativas'							then cantidad else 0 end
                ,[Otros]			    = case when Clasif not in ('Ingreso','Preingreso EP','Control Espontaneo','Control Agendado','Tareas Administrativas')  then cantidad else 0 end 



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


                        from CP_CargaAsistencial_MedicoAP aa
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
select * from #CP_Capacity_MedicoAP

                        --select * from  #SGP_tiempo0 aa

--select * from [Progreso_Actual] cc
--left join [dbo].[Siniestros_COVID19] bb on cc.Id_Siniestro=substring(bb.Siniestro_Covid19,4,len(bb.Siniestro_Covid19) )
--left join [dbo].[Siniestros_COVID19] bb on cast(aa.Siniestro as int)=cast(bb.Siniestro_Covid19 as int)
--left join [Progreso_Actual] cc on aa.Siniestro=cc.Id_Siniestro
--where cc.Id_Siniestro is not null and bb.Siniestro_Covid19 is not null

--select * from [dbo].[Siniestros_COVID19]
--select top 2 * from [Progreso_Actual]
