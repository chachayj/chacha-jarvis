package com.chacha.mapper;

import com.chacha.domain.SimpleValue;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface TestMapper {
    SimpleValue selectOne();
}
