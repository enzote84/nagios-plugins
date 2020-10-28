#!/bin/bash

# Author: Daniel Aristizabal
# Date: 14-11-2011
# Email: daristizabal@bbr.cl danielaristi@gmail.com
# Grupo DBA BBR
##################
# Modificaciones
# 20190129      Rodrigo Contreras
 

REETVAL=0
RUTA_PSQL=/var/lib/pgsql/
RUTALOG=${RUTA_PSQL}dba/log/
MD5LOG=md5sum.log
DISCO=85
MINUTOS=$1

if [ "$MINUTOS" == "" ];then
        MINUTOS=10
else
        if !  [ $MINUTOS -lt 120 ];then
        echo -e "\tSe recomienda tener un tiempo menor a 120 minutos, se ha ingresado \"$MINUTOS\""
        exit 1
        fi
fi


####################################################################################################################
#  verifica y o crea la ruta de logs
####################################################################################################################
if [ ! -d $RUTALOG  ];then
mkdir -p ${RUTALOG} > /dev/null 2>&1
	if [ ! $? -eq 0 ];then
		echo -e "\e[31m\n\n##########################################################################\n\n\tNO SE HA PODIDO CREAR LA RUTA DE LOGS ${RUTALOG} \n\n##########################################################################\n\n\e[0m"
		RETVAL=$[$RETVAL+1]
		exit $RETVAL
	fi
fi

####################################################################################################################
#  funcion para listar las bases de datos
####################################################################################################################

echo -e "\n"
echo -e "	==================================================================================    "
echo -e "	                   MONITOREO PARA BASES DE DATOS EN POSTGRES                          "
echo -e "	==================================================================================    "

psql -c "" > /dev/null 2>&1     #verifica que el servicio se este ejecutando
if [ $? -eq 0 ];then
dblist=$(psql -A -c 'SELECT datname FROM pg_catalog.pg_database;' |egrep -vi 'rows|filas|template|datname|postgres') #extrae la lista de las bases de datos
version=$(psql -At -c 'SELECT version();'|egrep -vi 'row|fila')
echo -e "\e[34m\n\t${version}\e[0m"
for i in $dblist;do      #ejecuta un ciclo con todos las funciones de chequeo para cada base de datos

echo -e "\n\t\t                  Base de datos ${i}"
echo -e "\t\t                -----------------------\n"

psql ${i} -c ""> /dev/null 2>&1       #verifica la conexion a una base de datos puntual
tmp=$?
RETVAL=$[$RETVAL+${tmp}]

if [ $tmp -eq 0 ];then
	echo -e "\t\tOK		existe conexion a la base de datos ${i}"
	else
	echo -e "\e[31m\t\tFALLO		no existe conexion a la base de datos ${i}\e[0m"
fi

#tablas=$(psql ${i} -tAc "select table_schema, table_name from  information_schema.tables where table_type='BASE TABLE' and table_schema!='pg_catalog' and table_schema!='information_schema';"|tr -t '|' '.')


tablas=$(psql ${i} -tAc "select table_schema, table_name from  information_schema.tables where table_type='BASE TABLE' and table_schema!='pg_catalog' and table_schema!='information_schema';"|tr -t '|' '.'|grep -vi vdp. | grep -vi vwp. | grep -vi vmp.| grep -vi public.ventadc | grep -vi public.ventamc | grep -vi public.ventawp )




####################################################################################################################
#  hace un select a todas las dables de una base de datos
####################################################################################################################
tr=0
for t in ${tablas};do
tr=0
psql ${i} -tAc "select 1 from ${t}  limit 1;">/dev/null 2>&1
if [ $? -ne 0 ];then
	echo -e "\e[31m\t\tFALLO		problema en la tabla ${t} para ${i}\e[0m"
	RETVAL=$[$RETVAL+1]
	tr=$[$tr+1]
fi
done
if [ $tr -eq 0 ];then
        echo -e "\t\tOK         \ttodas las tablas se pueden acceder"
fi
#######################################################################################################################


###################################llamado a una funcion potgres now()#################################################
psql -c "select now();">/dev/null 2>&1
if [ $? -ne 0 ];then
	echo -e "\e[31m\t\tFALLO		no se pudo extraer la hora, posible error\n\t\t\t\tde la base de datos\e[0m"
	RETVAL=$[$RETVAL+1]
	else
	echo -e "\t\tOK		exito al llamar a la funcion now()";
fi
#######################################################################################################################


#####################################monitoreo consultas con mas de una hora en ejecucion##############################
output=""
psql -tA -c "select exists(select * from pg_stat_activity where state = 'active' and (now()-query_start) > INTERVAL '${MINUTOS}' minute AND query NOT LIKE 'COPY %' AND query NOT LIKE '%sp_ventas_kardex()%' AND query NOT LIKE '%sp_procesa_stock_en_linea%')"|grep -qs f 
if [ $? -ne 0 ];then
output=$(psql -x -tA -c "select query from pg_stat_activity where state = 'active' and (now()-query_start) > INTERVAL '${MINUTOS}' minute AND query NOT LIKE 'COPY %'")
echo -e "\e[31m\t\tFALLO		Existen query's con mas de ${MINUTOS} min en ejecucion\n\t\t\t\t$output\e[0m"
RETVAL=$[$RETVAL+1]
else
echo -e "\t\tOK		No Existen query's ejecutandose"
fi
#######################################################################################################################


#####################################monitoreo cargas con mas de 2 horas en ejecucion##############################
output=""
psql -tA -c "select exists(select * from pg_stat_activity where state = 'active' and (now()-query_start) > INTERVAL '120' minute AND query LIKE 'COPY %')"|grep -qs f 
if [ $? -ne 0 ];then
output=$(psql -x -tA -c "select query from pg_stat_activity where state = 'active' and (now()-query_start) > INTERVAL '120' minute AND query LIKE 'COPY %'")
echo -e "\e[31m\t\tFALLO		Existen cargas con mas de 2 horas en ejecucion\n\t\t\t\t$output\e[0m"
RETVAL=$[$RETVAL+1]
else
echo -e "\t\tOK		No Existen query's de cargas con mas de 2 horas"
fi
#######################################################################################################################


#########################################################monitoreo prepared activos########################################
psql -tA -c "select exists (select * from pg_prepared_xacts where prepared <  now() - INTERVAL '10 minutes');"|grep -qs f
if [ $? -ne 0 ];then
echo -e "\e[31m\t\tFALLO		Existen prepared sin commit\e[0m"
RETVAL=$[$RETVAL+1]
else
echo -e "\t\tOK         	No Existen prepared sin commit"
fi
###########################################################################################################################


####################################################################################################################
#  verificacion de el espacio disponible en disco
####################################################################################################################
porcentaje=$(df /var/lib/pgsql/ -h | awk '{ print $0" COL6" }' |awk '{if($7 =="COL6"){ print $5} else print $4 }'|tr -d '%'|tail -1)
if [ $porcentaje -gt $DISCO ];then
	echo -e "\e[31m\t\tFALLO		para la particion /var/lib/pgsql hay\n\t\t\t\tmas de $DISCO % usado (${porcentaje}% usado)\e[0m"
	RETVAL=$[$RETVAL+1]
else
	echo -e "\t\tOK              para la particion /var/lib/pgsql hay\n\t\t\t\t${porcentaje}% usado"
fi
########################################################################################################################


echo -e "\n\t\t----------------------------------------------------------"
done
else
RETVAL=$[$RETVAL+1]
echo -e "\e[31m		NO SE PUEDE REALIZAR LA PRUEBA INICIAL DE CONEXION A LA BASE\n		DE DATOS POSTGRES, POSIBLEMENTE SERVICIO ABAJO\e[0m"
fi

echo -e "\n\n	**********************************************************************************    \n"


exit $RETVAL
