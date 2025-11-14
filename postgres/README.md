# postgres DB


현재는 행정구역만을 구성.


OSMB (OpenStreetMapBoundaries) : https://osm-boundaries.com/map

에서 osmb 바운더리 데이터 정보를 다운로드 한뒤

QGIS를 사용하여 db에 업로드한다.


그후 migration/administrative_from_OSMB.sql

의 마이그레이션 쿼리를 이용해서 행정구역 테이블에 데이터를 마이그레이션한다.


실질 데이터 백업은 datas 폴더 아래에 sql로 백업해두었음.