Set datefirst 1;
SET LANGUAGE spanish;

---------------------------------------------------------------------------------
--Tiempos por día
---------------------------------------------------------------------------------

drop table if exists #SGP_tiempo0
select --distinct
    aa.Centro, aa.Rut_Paciente, aa.Tipo_Atencion, aa.Minutos, aa.fecha, ca.Cl_Mov_Desc, ca.TipoSiniestro_Origen 
into #SGP_tiempo0
from CP_SGP aa
    left join 
        [az-analytics].[dbo].[DF_Interlocutor_Comercial] bb
        on 
        aa.Rut_Paciente=bb.Rut
    left join 
    -- select * from
        CP_CargaAsistencial_MedicoAP ca
        on 
        bb.Numero_BP=ca.Bp_Paciente
        and fecha=ca.Fecha_Inicio
    where fecha>'13-mar-2020' and 
        aa.centro not in ('CAA','Urgencia','CEM 3ER PISO', 'CEM 2DO PISO', 'CEM 1ER PISO', 'CEM 4TO PISO', 'CEM IMAGENOLOGIA','CEM 5TO PISO', 'CEM 6TO PISO', 'CEM RAYOS', 'Salud Mental')
         and aa.centro NOT LIKE '%SEL%'
         and Estado='box_atencion' and Descripcion_Tipo='atencion'
         and Cl_Mov_Desc is not null
         --and Rut_Paciente in ('18037427-2','20030789-5','20030789-5')
         order by fecha desc

drop table if EXISTS #SGP_tiempo1
select  Centro, Rut_Paciente, Tipo_Atencion, Minutos=max(Minutos), fecha,
Tipo = 
    case    when Cl_Mov_Desc='Consulta Urgenc' and TipoSiniestro_Origen='Enfermedad profesional' then 'Ingreso EP'
            when Cl_Mov_Desc='Consulta Urgenc' and TipoSiniestro_Origen!='Enfermedad profesional' then 'Ingreso'
            when Cl_Mov_Desc='Consulta Ambula' then 'Control Agendado'
            when Cl_Mov_Desc='Consulta Espont' then 'Control espontaneo'
            when Cl_Mov_Desc='Preingreso EP' then Cl_Mov_Desc
            when Cl_Mov_Desc in ('Por desarrollo', 'Apoyo Diagnosti', 'Apoyo Tratamien') then 'Tareas Admin'
            else 'Otros' 
            end



            
into #SGP_tiempo1
from #SGP_tiempo0
group by Centro, Rut_Paciente, Tipo_Atencion, Cl_Mov_Desc,TipoSiniestro_Origen, fecha

drop table if exists #tiempos_pordia
select Centro,  Tipo, Minutos=avg(cast(Minutos as float)), fecha
into #tiempos_pordia
from #SGP_tiempo1
group by Centro, Tipo, fecha




drop table if exists #tiempos_sede_dia
SELECT Centro,  fecha, Tareasadmin=isnull([Tareas Admin],6.0),
ControlesEspontaneos=isnull([Control espontaneo],15.0), ControlesAgendados=isnull([Control Agendado],15.0)
,Ingresos=isnull([Ingreso],20.6), IngresosEP=isnull([Ingreso EP],37.0), 
PreIngresoEP=isnull([Preingreso EP],28.0)
into #tiempos_sede_dia
from(
SELECT centro,  fecha, [Tareas Admin],[Otros],[Control espontaneo],[Control Agendado],[Ingreso],[Ingreso EP], [Preingreso EP]
    FROM #tiempos_pordia
PIVOT  
(  
avg(Minutos)
FOR Tipo in ([Tareas Admin],[Otros],[Control espontaneo],[Control Agendado],[Ingreso],[Ingreso EP], [Preingreso EP])
) AS PivotTable) aa


 --select * from #tiempos_sede_dia
--where centro in ('Parque las Americas','Alameda','Antofagasta') and fecha in ('2020-03-16', '2020-03-14')


-------- -------------------------------------------------------------------------
--Cálculo Carga Asistencial Médico AP - Cantidad de Atenciones por día 
---------------------------------------------------------------------------------

drop table if exists #CP_Capacity_MedicoAP;

Select 
    Territorio
    ,Agencia
    ,Centro
    ,fecha_inicio
    ,NumeroSemana
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

                        from CP_CargaAsistencial_MedicoAP
                        where Fecha_Inicio>'13-mar-2020'
                        group by
                        Territorio
                        ,agencia
                        ,centro
                        ,clasif
                        --,TipoDemanda
                        ,fecha_inicio
                        ,NumeroSemana
                        ,TipoSiniestro_Origen

                ) as hhh
  
    ) as hhhh

    group by 
    Territorio
    ,Agencia
    ,Centro
    ,fecha_inicio
    ,NumeroSemana

--select * from #CP_Capacity_MedicoAP_2
		
drop table if exists #CP_Capacity_MedicoAP_2;
select aa.Territorio, aa.Agencia, aa.Centro, aa.fecha_inicio
,Tiempo_total=aa.Ingreso*bb.Ingresos + aa.IngresoEP*bb.IngresosEP + aa.PreIngresoEP*bb.PreIngresoEP + aa.[Control Agendado]*bb.ControlesAgendados + aa.Control_espnt*bb.ControlesEspontaneos + aa.Administrativo*bb.Tareasadmin
    into #CP_Capacity_MedicoAP_2
    from #CP_Capacity_MedicoAP aa 
    left join #tiempos_sede_dia bb on aa.fecha_inicio=bb.Fecha and bb.Centro=aa.Centro
    where Fecha_Inicio>'2020-03-13'

select dmd.Territorio, dmd.Agencia, dmd.Centro, dmd.fecha_inicio, 
Tiempo_total=dmd.Tiempo_total/(9*60), oferta=ofert.FTE
from #CP_Capacity_MedicoAP_2 dmd
left join DI_CapacityVigente ofert on dmd.Centro=ofert.Centro 
where ofert.Cargo='Médico Atención Primaria' and Estado='Aprobado'
and fecha_inicio>='1-mar-2020' and dmd.Tiempo_total is not null
order by dmd.Territorio, dmd.Agencia, dmd.Centro, dmd.fecha_inicio