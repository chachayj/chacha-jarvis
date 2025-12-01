package com.chacha.entities.query;

import com.chacha.annotation.EntityInfo;
import com.chacha.annotation.EntityType;
import lombok.Getter;
import lombok.Setter;

@EntityInfo(
    tableName = "param: administrative_districts_query",
    entityType = EntityType.QUERY_DATAS,
    description = "도/광역시별 구 목록 조회 파라미터"
)
@Getter
@Setter
public class AdministrativeDistrictsQueryEntity {
    // 필수
    private String provinceCode;     // KR-SEOUL, KR-INCHEON

    // 선택
    // private String q;                // 부분 검색 (name / name_en)
    // private String sortBy;           // name | nameEn | adminLevel | districtCode
    // private String sortDir;          // asc | desc
    // private Integer page;            // 0-base
    // private Integer pageSize;        // 기본 20, 최대 200

    // 내부 계산용 (Service에서 세팅 후 Mapper로 전달)
    // private Integer limit;
    // private Integer offset;
}
