package com.chacha.mapper;

import com.chacha.entities.query.AdministrativeDistrictCentersQueryEntity;
import com.chacha.entities.query.AdministrativeDistrictsQueryEntity;
import com.chacha.entities.query.AdministrativeProvincesQueryEntity;
import com.chacha.entities.AdministrativeDistrictEntity;
import com.chacha.entities.BoundaryCenterEntity;
import com.chacha.entities.query.ProvinceCentersQueryEntity;
import com.chacha.entities.ProvinceEntity;
import org.apache.ibatis.annotations.Mapper;

import java.util.List;

@Mapper
public interface AdministrativeMapper {

    // 나라별 광역시·도 목록
    List<ProvinceEntity> selectProvinces(AdministrativeProvincesQueryEntity queryEntity);

    // 특정 광역의 동 중심점 목록
    List<BoundaryCenterEntity> selectCentersByProvince(ProvinceCentersQueryEntity queryEntity);

    // 특정 광역의 동 총 개수
    int countCentersByProvince(ProvinceCentersQueryEntity queryEntity);

    // 특정 구의 총 개수
    long countDistricts(AdministrativeDistrictsQueryEntity query);

    // 특정 구의 목록
    List<AdministrativeDistrictEntity> selectDistricts(AdministrativeDistrictsQueryEntity query);

    long countCentersByDistrict(AdministrativeDistrictCentersQueryEntity query);
    List<BoundaryCenterEntity> selectCentersByDistrict(AdministrativeDistrictCentersQueryEntity query);
}
