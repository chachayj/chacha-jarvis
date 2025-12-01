package com.chacha.entities.query;

import com.chacha.annotation.EntityInfo;
import com.chacha.annotation.EntityType;

import lombok.Getter;
import lombok.Setter;

@EntityInfo(
    tableName = "param: administrative_district_centers_query",
    entityType = EntityType.QUERY_DATAS,
    description = "구 코드 기준 동 경계 중심점 조회 파라미터"
)
@Getter
@Setter
public class AdministrativeDistrictCentersQueryEntity {
    private String districtCode;
    private Integer limit;
    private Integer offset;
}
