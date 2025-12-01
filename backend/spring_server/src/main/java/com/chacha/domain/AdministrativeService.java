package com.chacha.domain;

import com.chacha.request.DistrictCentersRequest;
import com.chacha.dto.BoundaryCenterDto;
import com.chacha.dto.DistrictsDTO;
import com.chacha.dto.GetDistrictsDTO;
import com.chacha.dto.ProvinceDto;
import com.chacha.entities.AdministrativeDistrictEntity;
import com.chacha.entities.BoundaryCenterEntity;
import com.chacha.entities.ProvinceEntity;
import com.chacha.entities.query.AdministrativeDistrictCentersQueryEntity;
import com.chacha.entities.query.AdministrativeDistrictsQueryEntity;
import com.chacha.entities.query.AdministrativeProvincesQueryEntity;
import com.chacha.entities.query.ProvinceCentersQueryEntity;

import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

import com.chacha.mapper.AdministrativeMapper;


@Service
public class AdministrativeService {

    private final AdministrativeMapper mapper;

    public AdministrativeService(AdministrativeMapper mapper) {
        this.mapper = mapper;
    }

    public List<ProvinceDto> getProvinces(String countryCode) {
        AdministrativeProvincesQueryEntity queryEntity = new AdministrativeProvincesQueryEntity();
        queryEntity.setCountryCode(countryCode);

        List<ProvinceEntity> entities = this.mapper.selectProvinces(queryEntity);
        return entities.stream().map(ProvinceDto::fromEntity).collect(Collectors.toList());
    }

    public int getCentersCount(String provinceCode) {
        ProvinceCentersQueryEntity queryEntity = new ProvinceCentersQueryEntity();
        queryEntity.setProvinceCode(provinceCode);
        return this.mapper.countCentersByProvince(queryEntity);
    }

    public List<BoundaryCenterDto> getCentersByProvince(String provinceCode, Integer limit, Integer offset) {
        ProvinceCentersQueryEntity queryEntity = new ProvinceCentersQueryEntity();
        queryEntity.setProvinceCode(provinceCode);
        queryEntity.setLimit(limit);
        queryEntity.setOffset(offset);

        List<BoundaryCenterEntity> rows = this.mapper.selectCentersByProvince(queryEntity);
        return rows.stream().map(BoundaryCenterDto::fromEntity).collect(Collectors.toList());
    }

    /** 구 목록 조회 - DTO로 반환 */
    public List<DistrictsDTO> findDistricts(GetDistrictsDTO dto) {
        AdministrativeDistrictsQueryEntity queryEntity = toDistrictsQuery(dto);
        List<AdministrativeDistrictEntity> rows = this.mapper.selectDistricts(queryEntity);
        return rows.stream()
                .map(DistrictsDTO::fromEntity)
                .collect(Collectors.toList());
    }

    /** 총 건수 조회 */
    public long getDistrictsTotal(GetDistrictsDTO dto) {
        return this.mapper.countDistricts(toDistrictsQuery(dto));
    }

    private AdministrativeDistrictsQueryEntity toDistrictsQuery(GetDistrictsDTO dto) {
        AdministrativeDistrictsQueryEntity queryEntity = new AdministrativeDistrictsQueryEntity();
        queryEntity.setProvinceCode(dto.getProvinceCode());
        // queryEntity.setQ(dto.getQ());
        // queryEntity.setSortBy(dto.getSortBy());
        // queryEntity.setSortDir(dto.getSortDir());
        // queryEntity.setLimit(dto.getLimit());
        // queryEntity.setOffset(dto.getOffset());
        return queryEntity;
    }

    public List<BoundaryCenterDto> getCentersByDistrict(DistrictCentersRequest request) {
        AdministrativeDistrictCentersQueryEntity queryEntity = new AdministrativeDistrictCentersQueryEntity();
        queryEntity.setDistrictCode(request.getDistrictCode());
        queryEntity.setLimit(request.getLimit());
        queryEntity.setOffset(request.getOffset());

        List<BoundaryCenterEntity> rows = this.mapper.selectCentersByDistrict(queryEntity);
        return rows.stream().map(BoundaryCenterDto::fromEntity).collect(Collectors.toList());
    }

    public long getCentersCount(DistrictCentersRequest request) {
        AdministrativeDistrictCentersQueryEntity queryEntity = new AdministrativeDistrictCentersQueryEntity();
        queryEntity.setDistrictCode(request.getDistrictCode());
        return this.mapper.countCentersByDistrict(queryEntity);
    }
}