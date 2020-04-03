package dev.appsody.jpa.model;

import java.io.Serializable;

import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.NamedQuery;

/**
 * The persistent class for the DEPARTMENT database table.
 */
@Entity
@NamedQuery(name="Department.findAll", query="SELECT d FROM Department d")
public class Department implements Serializable {
    private static final long serialVersionUID = 1L;
    private String deptno;
    private String deptname;
    private String location;

    public Department() {
    }

    public Department(String deptno, String deptname, String location) {
        super();
        this.deptno = deptno;
        this.deptname = deptname;
        this.location = location;
    }

    @Id
    public String getDeptno() {
        return this.deptno;
    }

    public void setDeptno(String deptno) {
        this.deptno = deptno;
    }

    public String getDeptname() {
        return this.deptname;
    }

    public void setDeptname(String deptname) {
        this.deptname = deptname;
    }

    public String getLocation() {
        return this.location;
    }

    public void setLocation(String location) {
        this.location = location;
    }

}
